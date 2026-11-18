#import "ProviderRun.h"

BOOL DPChatCheckMatches(NSDictionary *payload, NSDictionary *call) {
    if (![payload[@"input"] isKindOfClass:NSDictionary.class] || ![payload[@"input"] isEqual:call[@"input"]]) return NO;
    NSString *name = call[@"name"], *tool = payload[@"tool"], *space = payload[@"namespace"];
    if (![name isKindOfClass:NSString.class] || ![tool isKindOfClass:NSString.class]) return NO;
    if (![name hasPrefix:@"mcp__"]) return [name isEqual:tool] && (![space isKindOfClass:NSString.class] || !space.length);
    NSArray *parts = [name componentsSeparatedByString:@"__"];
    if (parts.count != 3 || ![space isKindOfClass:NSString.class]) return NO;
    NSString *namespace = parts[1];
    if ([namespace hasSuffix:@"-tools"]) namespace = [namespace substringToIndex:namespace.length - 6];
    return [namespace isEqual:space] && [parts[2] isEqual:tool];
}

@implementation DPChatRun (Safety)
- (void)cancel {
    NSArray *pending;
    @synchronized (self) { self.cancelled = YES; pending = self.reviews.allObjects; }
    [self.session cancel]; for (DPSafetyReview *review in pending) [review cancel];
}
- (void)permission:(NSDictionary *)message record:(NSDictionary *)record decision:(NSString *)decision reason:(NSString *)reason reply:(DPAgentReply)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        void (^complete)(BOOL) = ^(BOOL allowed) {
            reply(@{ @"type": @"ACK", @"msg": message[@"msg"], @"success": @YES,
                @"payload": @{ @"decision": allowed && !self.cancelled ? @"allow" : @"deny", @"reason": reason ?: @"" } });
        };
        if (self.cancelled || [decision isEqual:@"deny"]) { complete(NO); return; }
        NSString *tool = message[@"payload"][@"tool"];
        if ([@[@"Read", @"Write", @"Edit", @"upload_artifact"] containsObject:tool]) {
            if (record && DPApproveCustomChatFile(message, record[@"call"], record[@"work"], ^(NSDictionary *frame) {
                if (self.cancelled) complete(NO); else reply(frame);
            })) return;
            complete(NO); return;
        }
        if ([decision isEqual:@"allow"]) { complete(YES); return; }
        NSWindow *window = NSApp.keyWindow ?: NSApp.mainWindow;
        if (!window || window.attachedSheet) { complete(NO); return; }
        __block NSAlert *alert = [NSAlert new]; alert.messageText = [NSString stringWithFormat:@"Allow %@?", tool];
        NSData *data = [NSJSONSerialization dataWithJSONObject:message[@"payload"][@"input"] options:NSJSONWritingPrettyPrinted error:nil];
        if (data.length > 8192) { complete(NO); return; }
        alert.informativeText = [NSString stringWithFormat:@"%@\n\n%@", reason, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @""];
        [alert addButtonWithTitle:@"Cancel"]; [alert addButtonWithTitle:@"Allow"];
        [alert layout];
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) { complete(response == NSAlertSecondButtonReturn); alert = nil; }];
    });
}
- (BOOL)check:(NSDictionary *)message reply:(DPAgentReply)reply {
    if (![message[@"check"] isEqual:@"permission"] || ![message[@"msg"] isKindOfClass:NSString.class]) return NO;
    BOOL native = [self.provider[@"api"] isEqual:@"dia"], enabled = ![self.safety[@"api"] isEqual:@"disabled"];
    if (native && enabled) return NO; // Dia's own response stream includes its Watchtower result.
    NSDictionary *payload = message[@"payload"];
    NSString *identifier = payload[@"tool_use_id"];
    if (![identifier isKindOfClass:NSString.class] || ![payload[@"tool"] isKindOfClass:NSString.class] ||
        ![payload[@"input"] isKindOfClass:NSDictionary.class]) return NO;
    NSDictionary *record;
    @synchronized (self) { record = self.calls[identifier]; [self.calls removeObjectForKey:identifier]; }
    NSString *nativeName = [payload[@"namespace"] isEqual:@"dia"] && [payload[@"tool"] isEqual:@"upload_artifact"] ? @"mcp__dia-tools__upload_artifact" : payload[@"tool"];
    if (native && !record) record = @{ @"call": @{ @"id": identifier, @"name": nativeName, @"input": payload[@"input"] },
        @"work": DPChatWorkDirectory(self.body, self.context) ?: @"" };
    if (!native && !DPChatCheckMatches(payload, record[@"call"])) {
        [self permission:message record:nil decision:@"deny" reason:@"The tool check did not match this chat's proposed action." reply:reply]; return YES;
    }
    if (!enabled) { [self permission:message record:record decision:@"allow" reason:@"Model safety checks are disabled for this run." reply:reply]; return YES; }
    DPSafetyReview *review = [DPSafetyReview new];
    @synchronized (self) { [self.reviews addObject:review]; }
    __weak DPSafetyReview *weakReview = review;
    review.completion = ^(NSString *decision, NSString *reason) {
        @synchronized (self) { if (weakReview) [self.reviews removeObject:weakReview]; }
        [self permission:message record:record decision:decision reason:reason reply:reply];
        [DPProviderAudit record:@"safety-decision" fields:@{ @"api": self.provider[@"api"] ?: @"", @"decision": decision }];
    };
    NSMutableDictionary *provider = [self.provider mutableCopy]; provider[@"_safety"] = @YES;
    DPCheckCustomSafety(provider, DPSafetyBody(self.body, payload), review);
    return YES;
}
@end
