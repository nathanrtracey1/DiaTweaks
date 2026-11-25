#import "Patches/Boosts/Boosts.h"
#import "Settings/Settings.h"

// Every site with a Boost, each with its switch and a way to delete it without visiting the site. Settings builds its
// rows once per visit to the page, so the list rebuilds itself as Boosts change, with lines like a group's.
@interface DPBoostSiteList : NSStackView
@end

@implementation DPBoostSiteList

- (instancetype)init {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.alignment = NSLayoutAttributeLeading;
    self.spacing = 10;
    [self reload];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(boostsDidChange:) name:DPBoostsDidChangeNotification object:nil];
    return self;
}

// Not in the middle of the switch's own action.
- (void)boostsDidChange:(NSNotification *)notification {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reload) object:nil];
    [self performSelector:@selector(reload) withObject:nil afterDelay:0];
}

- (void)reload {
    for (NSView *view in self.arrangedSubviews.copy) [view removeFromSuperview];
    NSArray<NSString *> *domains = DPBoostDomains();
    if (!domains.count) [self addArrangedSubview:DPLabel(@"No site has a Boost yet.", 13, NSFontWeightRegular, NSColor.secondaryLabelColor)];
    for (NSString *domain in domains) {
        if (self.arrangedSubviews.count) {
            NSBox *line = [NSBox new];
            line.boxType = NSBoxSeparator;
            [self addArrangedSubview:line];
            [line.widthAnchor constraintEqualToAnchor:self.widthAnchor].active = YES;
        }
        NSSwitch *toggle = [NSSwitch new];
        toggle.state = [DPBoostFor(domain)[@"enabled"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        toggle.target = self;
        toggle.action = @selector(toggle:);
        NSButton *delete = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"trash" accessibilityDescription:@"Delete Boost"] target:self action:@selector(delete:)];
        delete.bordered = NO;
        delete.contentTintColor = NSColor.secondaryLabelColor;
        DPSetHint(delete, @"Delete Boost");
        for (NSControl *control in @[ toggle, delete ]) {
            control.identifier = domain;
            control.enabled = DPBoosts.on;
        }
        NSTextField *title = DPBoostLabel(@"");
        title.attributedStringValue = DPBoostTitle(DPBoostSiteName(domain), domain, NSFontWeightRegular);
        NSStackView *row = [NSStackView stackViewWithViews:@[ DPBoostFavicon(domain, 16), title ]];
        [row addView:delete inGravity:NSStackViewGravityTrailing];
        [row addView:toggle inGravity:NSStackViewGravityTrailing];
        [self addArrangedSubview:row];
        [row.widthAnchor constraintEqualToAnchor:self.widthAnchor].active = YES;
    }
}

- (void)toggle:(NSSwitch *)sender {
    NSMutableDictionary *boost = [DPBoostFor(sender.identifier) mutableCopy];
    if (!boost) return;  // Deleted since the list was built: saving nil would delete it again, quietly.
    boost[@"enabled"] = @(sender.state == NSControlStateValueOn);
    DPSaveBoost(sender.identifier, boost);
}

- (void)delete:(NSButton *)sender {
    NSString *domain = sender.identifier;
    NSAlert *alert = [NSAlert new];
    alert.messageText = [NSString stringWithFormat:@"Delete the Boost for %@?", domain];
    alert.informativeText = @"The site goes back to how it looks without it.";
    [alert addButtonWithTitle:@"Delete"].hasDestructiveAction = YES;
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) DPSaveBoost(domain, nil);
    }];
}

@end
// Settings puts each row in its own padding, so these are only what goes inside.
NSArray<NSView *> *DPBoostSettingsRows(void) {
    NSStackView *import = [NSStackView stackViewWithViews:@[ DPLabel(@"Import a Boost File…", 13, NSFontWeightRegular, NSColor.labelColor) ]];
    [import addView:DPSymbol(@"square.and.arrow.down", 13, NSColor.secondaryLabelColor) inGravity:NSStackViewGravityTrailing];
    NSView *list = [DPBoostSiteList new], *importRow = DPLinkRow(import, @"Import a Boost File", ^{ DPImportBoost(NSApp.keyWindow); });
    list.identifier = importRow.identifier = @"Sites";  // Their heading on the page.
    return @[ list, importRow ];
}
