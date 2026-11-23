#import "Providers.h"
#import "Settings/Settings.h"

void DPOrderChatModelOptions(NSView *page);

@interface DPChatModelStatusRow : NSView
@property NSTextField *status;
@property NSButton *usage;
- (void)sync;
@end
@implementation DPChatModelStatusRow
- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.status = DPLabel(@"", 12, NSFontWeightRegular, NSColor.secondaryLabelColor);
    self.status.accessibilityIdentifier = @"chatModelProviderStatus";
    self.usage = [NSButton buttonWithTitle:@"Manage usage" target:self action:@selector(usage:)];
    self.usage.bordered = NO; self.usage.contentTintColor = NSColor.linkColor;
    [self addSubview:self.status]; [self addSubview:self.usage];
    self.status.translatesAutoresizingMaskIntoConstraints = self.usage.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.status.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.status.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.status.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.usage.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.status.trailingAnchor constant:12],
        [self.usage.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.usage.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.usage.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor],
        [self.usage.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor],
    ]];
    return self;
}
- (void)usage:(id)sender { [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://chatgpt.com/settings/usage"]]; }
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self sync]; }
- (void)sync {
    NSDictionary *provider = DPSelectedChatAccount();
    BOOL apple = [provider[@"api"] isEqual:@"apple"];
    BOOL active = DPPatchNamed(@"chatModel")->on && (apple || [provider[@"api"] isEqual:@"chatgpt"]);
    BOOL connected = [provider[@"api"] isEqual:@"chatgpt"] && [provider[@"id"] length] &&
        [DPChatProviders credentialAvailable:provider[@"id"]] && !provider[@"error"];
    self.status.stringValue = apple ? @"Limited to basic page, web and file tools. Connectors aren’t supported." :
        connected ? @"Using ChatGPT plan" : @"Reconnect your ChatGPT account";
    self.usage.hidden = apple || !connected;
    NSView *row = self.superview;
    if ([row.superview isKindOfClass:NSStackView.class]) {
        NSArray *rows = ((NSStackView *)row.superview).arrangedSubviews;
        NSUInteger index = [rows indexOfObject:row];
        row.hidden = !active;
        if (index != NSNotFound && index > 0 && DPIsKind(rows[index - 1], "DPSeparatorView")) ((NSView *)rows[index - 1]).hidden = !active;
    }
}
@end

NSArray<NSView *> *DPChatGPTStatusRows(void) { return @[[DPChatModelStatusRow new]]; }
void DPRefreshChatGPTStatus(void) { for (DPChatModelStatusRow *row in DPFindViews("DPChatModelStatusRow")) [row sync]; }
static void DPChatGPTPage_sync(NSView *self, SEL _cmd) {
    DPCallOriginal(DPChatGPTPage_sync, self);
    DPOrderChatModelOptions(self);
    DPRefreshChatGPTStatus();
}
void DPInstallChatGPTPage(void) { DPHook("DPPageView", @selector(sync), (IMP)DPChatGPTPage_sync); }
