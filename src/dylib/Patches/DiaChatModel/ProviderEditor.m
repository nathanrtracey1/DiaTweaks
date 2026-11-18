#import "ProviderUI.h"

@implementation DPProviderEditor
- (instancetype)initWithProvider:(NSDictionary *)provider finished:(void (^)(void))finished {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.provider = provider; self.finished = finished;
    self.preset = [NSPopUpButton new];
    [self.preset addItemsWithTitles:@[@"OpenAI (API)", @"OpenAI (Account)", @"Anthropic", @"Google", @"Custom"]];
    self.preset.target = self; self.preset.action = @selector(preset:);
    self.format = [NSPopUpButton new]; [self.format addItemsWithTitles:@[@"Responses", @"Chat Completions", @"Anthropic Messages"]];
    self.name = [NSTextField new]; self.base = [NSTextField new]; self.key = [NSSecureTextField new];
    self.clear = [NSButton checkboxWithTitle:@"Remove saved API key" target:nil action:nil];
    self.advanced = [NSButton buttonWithTitle:@"Advanced" target:self action:@selector(disclose:)];
    [self.advanced setButtonType:NSButtonTypeOnOff]; self.advanced.bordered = NO;
    self.advanced.font = [NSFont systemFontOfSize:12]; self.advanced.contentTintColor = NSColor.secondaryLabelColor;
    self.key.placeholderString = provider ? @"Leave blank to keep saved key" : @"";
    self.form = [NSStackView new];
    self.problem = DPLabel(@"", 11, NSFontWeightRegular, NSColor.systemRedColor); self.problem.hidden = YES;
    DPFillStack(self, @[self.form]);
    if (provider) {
        NSUInteger index = [@[@"openai", @"chatgpt", @"anthropic", @"google", @"custom"] indexOfObject:[DPChatProviders preset:provider]];
        [self.preset selectItemAtIndex:index == NSNotFound ? 4 : index];
        [self.preset.menu itemAtIndex:1].hidden = YES;
    }
    [self preset:nil];
    if (provider) {
        self.name.stringValue = provider[@"name"]; self.base.stringValue = provider[@"baseURL"];
        [self.format selectItemAtIndex:[@[@"responses", @"chat-completions", @"anthropic"] indexOfObject:provider[@"api"]]];
    }
    self.accessibilityIdentifier = @"chatModelProviderEditor";
    return self;
}
- (void)preset:(id)sender {
    NSInteger index = self.preset.indexOfSelectedItem;
    self.name.stringValue = @[@"OpenAI", @"OpenAI", @"Anthropic", @"Google", @"Custom"][index];
    self.base.stringValue = @[@"https://api.openai.com/v1", @"", @"https://api.anthropic.com/v1",
        @"https://generativelanguage.googleapis.com/v1beta/openai", @"http://localhost:11434/v1"][index];
    [self.format selectItemAtIndex:index == 2 ? 2 : index == 3 ? 1 : 0];
    self.advanced.state = NSControlStateValueOff;
    [self render];
}
- (void)disclose:(id)sender { [self render]; }
- (void)render {
    NSInteger index = self.preset.indexOfSelectedItem;
    self.advanced.image = [NSImage imageWithSystemSymbolName:self.advanced.state ? @"chevron.down" : @"chevron.right" accessibilityDescription:nil];
    self.advanced.imagePosition = NSImageLeft;
    for (NSView *view in self.form.arrangedSubviews.copy) { [self.form removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSView *preset = DPRow(DPLabel(self.provider ? @"Edit Provider" : @"New Provider", 13, NSFontWeightSemibold, NSColor.labelColor), self.preset);
    NSMutableArray *rows = [NSMutableArray arrayWithObject:preset];
    if (index == 1) {
        NSButton *connect = DPChatGPTButton(); connect.target = self; connect.action = @selector(connect:);
        NSView *signIn = DPRow(DPLabel(@"Use your ChatGPT plan", 12, NSFontWeightRegular, NSColor.secondaryLabelColor), connect);
        [signIn.heightAnchor constraintGreaterThanOrEqualToAnchor:connect.heightAnchor constant:20].active = YES;
        [rows addObject:signIn];
    } else {
        NSMutableArray *controls = [NSMutableArray arrayWithObject:self.name];
        NSMutableArray *labels = [NSMutableArray arrayWithObject:@"Name"];
        if (index != 4) { [controls addObject:self.key]; [labels addObject:@"API key"]; }
        if (index == 4 || self.advanced.state) {
            [controls addObjectsFromArray:@[self.base, self.format]];
            [labels addObjectsFromArray:@[@"API base URL", @"API format"]];
        }
        if (index == 4) { [controls addObject:self.key]; [labels addObject:@"API key"]; }
        for (NSUInteger i = 0; i < controls.count; i++) {
            if (i == 2 && index != 4) [rows addObject:DPRow(self.advanced, [NSView new])];
            NSControl *control = controls[i]; control.accessibilityLabel = labels[i];
            [control setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
            [control setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
            NSView *row = DPRow(DPLabel(labels[i], 12, NSFontWeightRegular, NSColor.secondaryLabelColor), control);
            // DPRow hugs its trailing control; these fields must grow with the page.
            [control setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
            [control.widthAnchor constraintEqualToAnchor:row.widthAnchor multiplier:0.65].active = YES;
            [rows addObject:row];
        }
        if (index != 4 && !self.advanced.state) [rows addObject:DPRow(self.advanced, [NSView new])];
        if (self.provider) [rows addObject:DPRow(self.clear, [NSView new])];
    }
    NSMutableArray *actions = [NSMutableArray arrayWithObject:[NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancel:)]];
    if (index != 1) [actions addObject:[NSButton buttonWithTitle:@"Save Provider" target:self action:@selector(save:)]];
    [rows addObject:DPRow(self.problem, [NSStackView stackViewWithViews:actions])];
    DPFillStack(self.form, @[DPGroup(rows)]); DPProviderStretch(self);
}
- (void)cancel:(id)sender { self.finished(); }
- (void)connect:(id)sender { DPConnectChatGPTAccount(nil, self.window, self.finished); }
- (void)save:(id)sender {
    NSDictionary *provider = @{ @"id": self.provider[@"id"] ?: NSUUID.UUID.UUIDString, @"name": self.name.stringValue,
        @"baseURL": self.base.stringValue, @"api": @[@"responses", @"chat-completions", @"anthropic"][self.format.indexOfSelectedItem],
        @"preset": @[@"openai", @"chatgpt", @"anthropic", @"google", @"custom"][self.preset.indexOfSelectedItem] };
    NSString *secret = self.clear.state == NSControlStateValueOn ? @"" : self.key.stringValue.length ? self.key.stringValue : nil;
    NSString *error = [DPChatProviders save:provider key:secret];
    if (!error) { self.key.stringValue = @""; self.finished(); return; }
    self.problem.stringValue = error; self.problem.hidden = NO;
}
@end
