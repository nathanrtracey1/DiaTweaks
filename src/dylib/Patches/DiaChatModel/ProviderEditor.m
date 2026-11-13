#import "ProviderUI.h"

@interface DPProviderEditor : NSObject
@property NSPopUpButton *preset, *format;
@property NSTextField *name, *base;
@end
@implementation DPProviderEditor
- (void)preset:(id)sender {
    NSInteger index = self.preset.indexOfSelectedItem;
    self.name.stringValue = self.preset.titleOfSelectedItem;
    self.base.stringValue = @[@"https://api.openai.com/v1", @"https://api.anthropic.com/v1",
        @"https://generativelanguage.googleapis.com/v1beta/openai", @"http://localhost:11434/v1"][index];
    [self.format selectItemAtIndex:index == 1 ? 2 : index == 2 ? 1 : 0];
}
@end

void DPEditProvider(NSDictionary *existing, NSWindow *window, void (^finished)(NSString *)) {
    DPProviderEditor *editor = [DPProviderEditor new];
    editor.preset = [NSPopUpButton new]; [editor.preset addItemsWithTitles:@[@"OpenAI", @"Anthropic", @"Google", @"Custom"]];
    editor.preset.target = editor; editor.preset.action = @selector(preset:);
    editor.format = [NSPopUpButton new]; [editor.format addItemsWithTitles:@[@"Responses", @"Chat Completions", @"Anthropic Messages"]];
    editor.name = [NSTextField new]; editor.base = [NSTextField new];
    NSSecureTextField *key = [NSSecureTextField new];
    key.placeholderString = existing ? @"Leave blank to keep the saved key" : @"API key (optional for local servers)";
    [editor preset:nil];
    if (existing) {
        editor.name.stringValue = existing[@"name"]; editor.base.stringValue = existing[@"baseURL"];
        [editor.preset selectItemAtIndex:3];
        [editor.format selectItemAtIndex:[@[@"responses", @"chat-completions", @"anthropic"] indexOfObject:existing[@"api"]]];
    }
    NSMutableArray *views = [NSMutableArray new];
    NSArray *controls = @[editor.preset, editor.name, editor.base, editor.format, key];
    NSArray *labels = @[@"Provider", @"Account name", @"API base URL", @"API format", @"API key"];
    for (NSUInteger i = 0; i < controls.count; i++) {
        NSControl *control = controls[i]; control.accessibilityLabel = labels[i];
        [control.widthAnchor constraintEqualToConstant:420].active = YES;
        [views addObjectsFromArray:@[[NSTextField labelWithString:labels[i]], control]];
    }
    NSStackView *form = DPProviderColumn(views);
    form.frame = NSMakeRect(0, 0, 420, 330);
    NSAlert *alert = [NSAlert new]; alert.messageText = existing ? @"Edit Provider" : @"Add Provider";
    alert.accessoryView = form; [alert addButtonWithTitle:@"Save"]; [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn) { finished(nil); return; }
        NSString *identifier = existing[@"id"] ?: NSUUID.UUID.UUIDString;
        NSDictionary *provider = @{ @"id": identifier, @"name": editor.name.stringValue,
            @"baseURL": editor.base.stringValue, @"api": @[@"responses", @"chat-completions", @"anthropic"][editor.format.indexOfSelectedItem] };
        NSString *error = [DPChatProviders save:provider key:key.stringValue.length ? key.stringValue : nil];
        if (error) { NSAlert *failure = [NSAlert new]; failure.messageText = error; [failure beginSheetModalForWindow:window completionHandler:nil]; }
        finished(error ? nil : identifier);
    }];
}
