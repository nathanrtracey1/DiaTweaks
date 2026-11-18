#import "ProviderRun.h"

static void DPModelReply(DPAgentReply reply, NSString *message, NSDictionary *payload, BOOL success) {
    reply(@{ @"type": @"ACK", @"msg": message, @"success": @(success), @"payload": payload });
}

@implementation DPChatRun
- (BOOL)consume:(NSDictionary *)message reply:(DPAgentReply)reply {
    NSDictionary *payload = message[@"payload"];
    if (![payload isKindOfClass:NSDictionary.class]) return NO;
    if ([message[@"type"] isEqual:@"CHECK"]) {
        return [self check:message reply:reply];
    }
    if (![message[@"type"] isEqual:@"LLM_REQUEST"] || ![message[@"msg"] isKindOfClass:NSString.class]) return NO;
    id body = payload[@"body"];
    if ([body isKindOfClass:NSString.class]) body = [body dataUsingEncoding:NSUTF8StringEncoding];
    if ([body isKindOfClass:NSData.class]) body = [NSJSONSerialization JSONObjectWithData:body options:0 error:nil];
    NSString *msg = message[@"msg"];
    if (![body isKindOfClass:NSDictionary.class]) {
        DPModelReply(reply, msg, @{ @"error": @"Dia sent an unsupported model request." }, NO); return YES;
    }
    self.body = body;
    if ([self.provider[@"api"] isEqual:@"dia"]) return NO;
    body = DPInlineChatAttachments(body, self.context);
    self.body = body;
    if ([payload[@"endpoint"] isEqual:@"count-tokens"]) {
        NSUInteger estimate = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil].length;
        DPModelReply(reply, msg, @{ @"status_code": @200, @"headers": @{ @"content-type": @"application/json" },
            @"data": [NSString stringWithFormat:@"{\"input_tokens\":%lu}", (unsigned long)estimate], @"done": @YES }, YES);
        return YES;
    }
    if (![payload[@"endpoint"] isEqual:@"messages"] || ![body[@"messages"] isKindOfClass:NSArray.class]) {
        DPModelReply(reply, msg, @{ @"error": @"This Dia inference format is not supported by the selected provider." }, NO); return YES;
    }
    NSString *work = DPChatWorkDirectory(body, self.context);
    __block BOOL started = NO;
    [self.session start:body chunk:^(NSString *chunk) {
        NSDictionary *part = started ? @{ @"data": chunk } : @{ @"status_code": @200,
            @"headers": @{ @"content-type": @"text/event-stream" }, @"data": chunk };
        started = YES;
        DPModelReply(reply, msg, part, YES);
    } calls:^(NSArray *calls) {
        @synchronized (self) {
            for (NSDictionary *call in calls) self.calls[call[@"id"]] = @{ @"call": call, @"work": work ?: @"" };
        }
    } completion:^(NSString *error) {
        if (!error) { DPModelReply(reply, msg, @{ @"done": @YES }, YES); return; }
        NSDictionary *failure = @{ @"type": @"error", @"error": @{ @"type": @"invalid_request_error", @"message": error } };
        NSString *json = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:failure options:0 error:nil] encoding:NSUTF8StringEncoding];
        // An IPC failure is retried by Dia; provider capability errors must reach the chat once.
        NSString *data = started ? [NSString stringWithFormat:@"event: error\ndata: %@\n\n", json] : json;
        NSMutableDictionary *part = [@{ @"data": data, @"done": @YES } mutableCopy];
        if (!started) { part[@"status_code"] = @400; part[@"headers"] = @{ @"content-type": @"application/json" }; part[@"body"] = json; }
        DPModelReply(reply, msg, part, YES);
    }];
    return YES;
}
@end
