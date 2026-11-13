#import "Providers.h"

BOOL DPApproveCustomChatFile(NSDictionary *frame, NSDictionary *call, NSString *work, DPAgentReply reply) {
    if (![frame[@"check"] isEqual:@"permission"] || ![frame[@"msg"] isKindOfClass:NSString.class]) return NO;
    NSDictionary *payload = frame[@"payload"], *expected = call[@"input"];
    if (![payload isKindOfClass:NSDictionary.class] || ![payload[@"input"] isKindOfClass:NSDictionary.class]) return NO;
    NSString *tool = call[@"name"];
    BOOL upload = [tool isEqual:@"mcp__dia-tools__upload_artifact"];
    BOOL write = [tool isEqual:@"Write"] || [tool isEqual:@"Edit"];
    if (upload) {
        if (![payload[@"tool"] isEqual:@"upload_artifact"] || ![payload[@"namespace"] isEqual:@"dia"]) return NO;
    } else if (![payload[@"tool"] isEqual:tool] || (!write && ![tool isEqual:@"Read"]) ||
               ([payload[@"namespace"] isKindOfClass:NSString.class] && [payload[@"namespace"] length])) return NO;
    NSString *(^operationPath)(NSDictionary *) = ^NSString *(NSDictionary *input) {
        return upload ? DPReportEntry(input, work) : DPAbsoluteChatPath(input[@"file_path"], work);
    };
    NSString *file = operationPath(expected), *actual = operationPath(payload[@"input"]);
    if (![actual isEqual:file] || !DPPathInsideChat(file, work, write)) return NO;
    NSString *msg = frame[@"msg"];
    dispatch_async(dispatch_get_main_queue(), ^{
        void (^complete)(BOOL) = ^(BOOL approved) {
            BOOL allowed = approved && [operationPath(expected) isEqual:file] && DPPathInsideChat(file, work, write);
            reply(@{ @"type": @"ACK", @"msg": msg, @"success": @YES,
                     @"payload": @{ @"decision": allowed ? @"allow" : @"deny" } });
        };
        NSWindow *window = NSApp.keyWindow ?: NSApp.mainWindow;
        if (!window || window.attachedSheet) { complete(NO); return; }
        NSAlert *alert = [NSAlert new];
        alert.messageText = upload ? @"Allow the custom model to attach this file to Dia Chat?" :
            [NSString stringWithFormat:@"Allow the custom model to %@ this chat file?", write ? @"write" : @"read"];
        alert.informativeText = [file substringFromIndex:work.length + 1];
        [alert addButtonWithTitle:@"Cancel"];
        [alert addButtonWithTitle:@"Allow"];
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
            complete(result == NSAlertSecondButtonReturn);
        }];
    });
    return YES;
}
