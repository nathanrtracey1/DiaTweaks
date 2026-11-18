#import "ProviderUI.h"

@implementation DPProviderCard (Editing)
- (void)remove:(id)sender {
    NSAlert *alert = [NSAlert new]; alert.messageText = @"Remove this provider and its saved credential?";
    [alert addButtonWithTitle:@"Cancel"]; [alert addButtonWithTitle:@"Remove"];
    NSString *identifier = self.provider[@"id"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertSecondButtonReturn) return;
        if ([self.provider[@"api"] isEqual:@"chatgpt"]) {
            [DPChatGPT signOut:identifier completion:^(NSString *error) { [self problem:[DPChatProviders remove:identifier] ?: error]; }];
        } else [self problem:[DPChatProviders remove:identifier]];
    }];
}
- (void)manual:(id)sender {
    NSString *model = [self.modelID.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [self problem:[DPChatProviders addModel:self.provider[@"id"] model:model]];
}
@end
