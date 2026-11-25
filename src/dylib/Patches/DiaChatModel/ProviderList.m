#import "ProviderUI.h"

NSStackView *DPProviderColumn(NSArray<NSView *> *views) { return DPColumn(views, 10); }

void DPProviderStretch(NSView *view) {
    if ([view isKindOfClass:NSStackView.class]) [(NSStackView *)view setHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    for (NSView *child in view.subviews) DPProviderStretch(child);
}

@implementation DPProviderList
- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.orientation = NSUserInterfaceLayoutOrientationVertical; self.spacing = 12;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:@"DPChatProvidersChanged" object:nil];
    [self reload];
    if (!DPTesting) for (NSDictionary *account in DPChatProviders.accounts)
        [DPChatProviders refresh:account[@"id"] force:NO completion:^(NSString *error) {}];
    return self;
}
- (void)add:(id)sender { [self edit:nil]; }
- (void)edit:(NSDictionary *)provider {
    __weak DPProviderList *list = self;
    self.editor = [[DPProviderEditor alloc] initWithProvider:provider finished:^{
        list.editor = nil; [list reload];
    }];
    [self reload];
    [self.window.contentView layoutSubtreeIfNeeded];
    [self.editor scrollRectToVisible:self.editor.bounds];
}
- (void)reload {
    for (NSView *view in self.arrangedSubviews.copy) { [self removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSString *editingID = ((DPProviderEditor *)self.editor).provider[@"id"];
    NSButton *add = [NSButton buttonWithTitle:@"Add Provider…" target:self action:@selector(add:)];
    add.accessibilityIdentifier = @"chatModelAddProvider";
    NSStackView *actions = [NSStackView stackViewWithViews:@[add]];
    actions.hidden = self.editor && !editingID.length;
    actions.alignment = NSLayoutAttributeLeading;
    actions.orientation = NSUserInterfaceLayoutOrientationVertical;
    actions.spacing = 12;
    [self addArrangedSubview:actions];
    [actions.widthAnchor constraintEqualToAnchor:self.widthAnchor].active = YES;
    if (self.editor && !editingID.length) {
        [self addArrangedSubview:self.editor];
        [self.editor.widthAnchor constraintEqualToAnchor:self.widthAnchor].active = YES;
    }
    for (NSDictionary *account in DPChatProviders.accounts) {
        NSView *card = [editingID isEqual:account[@"id"]] ? self.editor : [[DPProviderCard alloc] initWithProvider:account];
        [self addArrangedSubview:card];
        [card.widthAnchor constraintEqualToAnchor:self.widthAnchor].active = YES;
    }
    DPProviderStretch(self);
    DPPatch *patch = DPPatchNamed(@"chatModel");
    if (patch) DPFindView(self, ^BOOL(NSView *view) {
        BOOL label = [view isKindOfClass:NSTextField.class] && !((NSTextField *)view).editable;
        if ([view isKindOfClass:NSControl.class] && !label) ((NSControl *)view).enabled = patch->on;
        return NO;
    });
}
@end

NSView *DPInlineProviderList(void) {
    DPProviderList *list = [DPProviderList new]; list.identifier = @"Providers";
    list.accessibilityIdentifier = @"chatModelProviders"; return list;
}
