#import "ProviderUI.h"

@implementation DPProviderCard
- (instancetype)initWithProvider:(NSDictionary *)provider {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.provider = provider;
    NSString *api = provider[@"api"];
    BOOL apple = [api isEqual:@"apple"], chatGPT = [api isEqual:@"chatgpt"];
    NSString *subtitle = apple ? @"On this Mac" : chatGPT ? @"ChatGPT account" : provider[@"baseURL"];
    NSTextField *name = DPLabel(provider[@"name"], 13, NSFontWeightSemibold, NSColor.labelColor);
    name.toolTip = subtitle;
    NSButton *future = [NSButton checkboxWithTitle:@"Add future models automatically" target:self action:@selector(future:)];
    future.state = [provider[@"autoAdd"] boolValue]; future.controlSize = NSControlSizeSmall;
    NSStackView *heading = [NSStackView stackViewWithViews:@[
        DPProviderIcon(provider),
        DPColumn(@[name, future], 4)]];
    NSMutableArray *buttons = [NSMutableArray new];
    if (!apple) {
        [buttons addObject:[NSButton buttonWithTitle:chatGPT ? @"Reconnect" : @"Edit" target:self action:@selector(edit:)]];
        [buttons addObject:[NSButton buttonWithTitle:@"Remove" target:self action:@selector(remove:)]];
    }
    NSMutableArray *rows = [NSMutableArray arrayWithObject:DPRow(heading, [NSStackView stackViewWithViews:buttons])];
    NSMutableArray *models = [NSMutableArray new];
    for (NSDictionary *model in provider[@"catalog"]) {
        NSButton *toggle = [NSButton checkboxWithTitle:@"" target:self action:@selector(model:)];
        toggle.identifier = model[@"id"]; toggle.accessibilityLabel = [@"Show " stringByAppendingString:model[@"name"]];
        toggle.state = [provider[@"visibility"][model[@"id"]] boolValue];
        NSMutableArray *labels = [NSMutableArray arrayWithObject:DPLabel(model[@"name"], 13, NSFontWeightRegular, NSColor.labelColor)];
        if (![model[@"name"] isEqual:model[@"id"]]) [labels addObject:DPLabel(model[@"id"], 11, NSFontWeightRegular, NSColor.secondaryLabelColor)];
        [models addObject:DPRow(DPColumn(labels, 2), toggle)];
    }
    if (models.count) [rows addObject:DPProviderModels(models)];
    else [rows addObject:DPRow(DPLabel(@"No models yet", 12, NSFontWeightRegular, NSColor.secondaryLabelColor), [NSView new])];
    NSMutableArray *actions = [NSMutableArray arrayWithObjects:
        [NSButton buttonWithTitle:@"Select All" target:self action:@selector(all:)],
        [NSButton buttonWithTitle:@"Deselect All" target:self action:@selector(none:)],
        [NSButton buttonWithTitle:@"Refresh Models" target:self action:@selector(refresh:)], nil];
    if (chatGPT) [actions addObject:[NSButton buttonWithTitle:@"Sign Out" target:self action:@selector(signOut:)]];
    NSStackView *actionStack = [NSStackView stackViewWithViews:actions]; actionStack.spacing = 6;
    [rows addObject:DPRow(actionStack, [NSView new])];
    if (!apple) {
        self.modelID = [NSTextField new]; self.modelID.placeholderString = @"Model ID"; self.modelID.accessibilityLabel = @"Model ID";
        [self.modelID setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self.modelID setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [rows addObject:DPRow(self.modelID, [NSButton buttonWithTitle:@"Add Model" target:self action:@selector(manual:)])];
    }
    self.status = DPLabel([DPChatProviders status:provider[@"id"]] ?: @"", 11, NSFontWeightRegular, NSColor.secondaryLabelColor);
    if (self.status.stringValue.length) [rows addObject:DPRow(self.status, [NSView new])];
    DPFillStack(self, @[DPGroup(rows)]);
    self.accessibilityIdentifier = provider[@"id"];
    return self;
}
- (void)problem:(NSString *)message {
    if (!message.length) return;
    NSAlert *alert = [NSAlert new]; alert.messageText = message;
    if (self.window && !self.window.attachedSheet) [alert beginSheetModalForWindow:self.window completionHandler:nil];
}
- (void)model:(NSButton *)sender { [self problem:[DPChatProviders visibility:self.provider[@"id"] model:sender.identifier shown:sender.state == NSControlStateValueOn]]; }
- (void)all:(id)sender { [self problem:[DPChatProviders showAll:self.provider[@"id"] shown:YES]]; }
- (void)none:(id)sender { [self problem:[DPChatProviders showAll:self.provider[@"id"] shown:NO]]; }
- (void)future:(NSButton *)sender { [self problem:[DPChatProviders futureModels:self.provider[@"id"] enabled:sender.state == NSControlStateValueOn]]; }
- (void)refresh:(id)sender { [DPChatProviders refresh:self.provider[@"id"] force:YES completion:^(NSString *error) { [self problem:error]; }]; }
- (void)edit:(id)sender {
    if ([self.provider[@"api"] isEqual:@"chatgpt"]) DPConnectChatGPT(self.provider[@"id"], self.window);
    else for (NSView *view = self.superview; view; view = view.superview)
        if ([view isKindOfClass:DPProviderList.class]) { [(DPProviderList *)view edit:self.provider]; break; }
}
- (void)signOut:(id)sender { [DPChatGPT signOut:self.provider[@"id"] completion:^(NSString *error) { [self problem:error]; }]; }
@end
