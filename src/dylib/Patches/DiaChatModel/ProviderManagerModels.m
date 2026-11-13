#import "ProviderUI.h"

@implementation DPProviderManager (Models)
- (NSInteger)numberOfRowsInTableView:(NSTableView *)table {
    return [[DPChatProviders account:self.identifier ?: @""][@"catalog"] count];
}
- (NSView *)tableView:(NSTableView *)table viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    NSDictionary *account = [DPChatProviders account:self.identifier ?: @""];
    NSArray *catalog = account[@"catalog"];
    if ((NSUInteger)row >= catalog.count) return nil;
    NSDictionary *model = catalog[row];
    if ([column.identifier isEqual:@"Show"]) {
        NSButton *toggle = [NSButton checkboxWithTitle:@"" target:self action:@selector(model:)];
        toggle.identifier = model[@"id"];
        toggle.accessibilityLabel = [@"Show " stringByAppendingString:model[@"name"]];
        toggle.state = [account[@"visibility"][model[@"id"]] boolValue];
        return toggle;
    }
    return [NSTextField labelWithString:model[[column.identifier isEqual:@"Model"] ? @"name" : @"id"] ?: @""];
}
- (void)model:(NSButton *)sender {
    [self problem:[DPChatProviders visibility:self.identifier model:sender.identifier shown:sender.state == NSControlStateValueOn]];
}
- (void)all:(id)sender { if (self.identifier) [self problem:[DPChatProviders showAll:self.identifier shown:YES]]; }
- (void)none:(id)sender { if (self.identifier) [self problem:[DPChatProviders showAll:self.identifier shown:NO]]; }
- (void)future:(NSButton *)sender {
    if (self.identifier) [self problem:[DPChatProviders futureModels:self.identifier enabled:sender.state == NSControlStateValueOn]];
}
- (void)refresh:(id)sender {
    if (!self.identifier) return;
    [self problem:@"Loading models…"];
    [DPChatProviders refresh:self.identifier force:YES completion:^(NSString *error) { [self problem:error ?: @"Models refreshed."]; }];
}
- (void)add:(id)sender {
    DPEditProvider(nil, self.window, ^(NSString *identifier) { if (identifier) self.identifier = identifier; [self reload]; });
}
- (void)edit:(id)sender {
    NSDictionary *provider = [DPChatProviders account:self.identifier ?: @""];
    if ([provider[@"api"] isEqual:@"apple"]) { [self problem:@"Apple Intelligence uses the on-device model and needs no API key."]; return; }
    if (provider) DPEditProvider(provider, self.window, ^(NSString *identifier) { [self reload]; });
}
- (void)remove:(id)sender {
    if (!self.identifier) return;
    NSAlert *alert = [NSAlert new]; alert.messageText = @"Remove this provider and its saved credential?";
    [alert addButtonWithTitle:@"Cancel"]; [alert addButtonWithTitle:@"Remove"];
    NSString *identifier = self.identifier;
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertSecondButtonReturn) [self problem:[DPChatProviders remove:identifier]];
    }];
}
- (void)manual:(id)sender {
    if (!self.identifier) return;
    NSAlert *alert = [NSAlert new]; alert.messageText = @"Add a model ID";
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 350, 24)]; alert.accessoryView = field;
    [alert addButtonWithTitle:@"Add"]; [alert addButtonWithTitle:@"Cancel"];
    NSString *identifier = self.identifier;
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn || !field.stringValue.length) return;
        [self problem:[DPChatProviders addModel:identifier model:field.stringValue]];
    }];
}
@end
