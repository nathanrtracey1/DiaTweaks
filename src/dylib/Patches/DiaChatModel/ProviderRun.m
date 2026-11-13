#import "ProviderRun.h"

static void DPModelReply(DPAgentReply reply, NSString *message, NSDictionary *payload, BOOL success) {
    reply(@{ @"type": @"ACK", @"msg": message, @"success": @(success), @"payload": payload });
}

@implementation DPChatRun
- (BOOL)consume:(NSDictionary *)message reply:(DPAgentReply)reply {
    NSDictionary *payload = message[@"payload"];
    if (![payload isKindOfClass:NSDictionary.class]) return NO;
    if ([message[@"type"] isEqual:@"CHECK"]) {
        NSString *identifier = payload[@"tool_use_id"];
        if (![identifier isKindOfClass:NSString.class]) return NO;
        NSDictionary *record;
        @synchronized (self) { record = self.calls[identifier]; [self.calls removeObjectForKey:identifier]; }
        return record && DPApproveCustomChatFile(message, record[@"call"], record[@"work"], reply);
    }
    if (![message[@"type"] isEqual:@"LLM_REQUEST"] || ![message[@"msg"] isKindOfClass:NSString.class]) return NO;
    id body = payload[@"body"];
    if ([body isKindOfClass:NSString.class]) body = [body dataUsingEncoding:NSUTF8StringEncoding];
    if ([body isKindOfClass:NSData.class]) body = [NSJSONSerialization JSONObjectWithData:body options:0 error:nil];
    NSString *msg = message[@"msg"];
    if (![body isKindOfClass:NSDictionary.class]) {
        DPModelReply(reply, msg, @{ @"error": @"Dia sent an unsupported model request." }, NO); return YES;
    }
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
        if (!work) return;
        @synchronized (self) {
            for (NSDictionary *call in calls) self.calls[call[@"id"]] = @{ @"call": call, @"work": work };
        }
    } completion:^(NSString *error) {
        DPModelReply(reply, msg, error ? @{ @"error": error } : @{ @"done": @YES }, error == nil);
    }];
    return YES;
}
@end
