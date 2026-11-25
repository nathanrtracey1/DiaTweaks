#import "Patches/Boosts/Editor.h"

static const CGFloat DPLookWidth = 184, DPCodeWidth = 340, DPEditorInset = 18;

@implementation DPBoostEditor (Layout)

// Arc's title bar: close, the Boost's name over a menu, and reset. A Boost here is a site's, so it has the site's name.
- (NSView *)makeHeading {
    NSPopUpButton *menu = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:YES];
    menu.bordered = NO;
    menu.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [menu setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [menu addItemWithTitle:DPBoostSiteName(self.domain)];
    [menu.menu addItemWithTitle:self.domain action:nil keyEquivalent:@""];
    self.onItem = [menu.menu addItemWithTitle:@"Boost On" action:@selector(toggleOn:) keyEquivalent:@""];
    self.onItem.state = [self.boost[@"enabled"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    [menu.menu addItem:NSMenuItem.separatorItem];
    [menu.menu addItemWithTitle:@"Import Boost File…" action:@selector(importBoost:) keyEquivalent:@""];
    [menu.menu addItemWithTitle:@"Export Boost File…" action:@selector(exportBoost:) keyEquivalent:@""];
    [menu.menu addItem:NSMenuItem.separatorItem];
    [menu.menu addItemWithTitle:@"Delete Boost…" action:@selector(deleteBoost:) keyEquivalent:@""];
    for (NSMenuItem *item in menu.itemArray) item.target = self;
    __weak NSPopUpButton *weakMenu = menu;
    if ([DPFrontDomain() isEqual:self.domain]) DPPageSiteName(DPFrontContents(), ^(NSString *name) { weakMenu.title = name; });

    NSStackView *heading = [NSStackView new];
    [heading addView:DPBoostIconButton(@"xmark.circle.fill", @"Close", self, @selector(closeEditor:)) inGravity:NSStackViewGravityLeading];
    [heading addView:menu inGravity:NSStackViewGravityCenter];
    [heading addView:DPBoostIconButton(@"arrow.counterclockwise", @"Reset Colors, Font, Size and Case", self, @selector(resetLook:)) inGravity:NSStackViewGravityTrailing];
    return heading;
}

// Under the pad: light or dark, a slider for how light, and the site's own colors again.
- (NSView *)makeColorTiles {
    self.bulb = DPSymbol(@"lightbulb", 13, NSColor.labelColor);
    self.noColor = DPSymbol(@"nosign", 13, NSColor.labelColor);
    self.light = [NSSlider sliderWithValue:50 minValue:0 maxValue:100 target:self action:@selector(lightChanged:)];
    self.light.controlSize = NSControlSizeSmall;
    self.light.accessibilityLabel = @"Brightness";
    self.light.hidden = YES;
    return DPBoostTileRow(@[
        DPBoostTile(self.bulb, @"Light or Dark", self, @selector(toggleDark:)),
        DPBoostTile(DPSymbol(@"slider.horizontal.3", 13, NSColor.labelColor), @"Brightness", self, @selector(toggleLight:)),
        DPBoostTile(self.noColor, @"No Color", self, @selector(clearColor:)),
    ]);
}

- (NSView *)makeContent {
    self.pad = [DPBoostColorPad new];
    __weak DPBoostEditor *weakSelf = self;
    self.pad.picked = ^(double hue, double sat, BOOL done) { [weakSelf pickHue:hue sat:sat done:done]; };
    NSView *colors = [self makeColorTiles];
    self.fonts = DPBoostFontGrid(self, @selector(pickFont:));
    self.sizeLabel = DPBoostTileLabel(@"Size");
    self.caseLabel = DPBoostTileLabel(@"Case");
    NSView *text = DPBoostTileRow(@[ DPBoostTile(self.sizeLabel, @"Size", self, @selector(nextSize:)), DPBoostTile(self.caseLabel, @"Case", self, @selector(nextCase:)) ]);
    NSView *code = DPBoostBarTile(DPBoostTileLabel(@"Code"), DPSymbol(@"curlybraces", 13, NSColor.labelColor), @"Code", self, @selector(showCodePage:));

    NSStackView *look = [NSStackView new];
    DPFillStack(look, @[ [self makeHeading], self.pad, colors, self.light, self.fonts, text, [self makeZapGroup], code ]);
    look.spacing = 12;
    for (NSView *view in look.arrangedSubviews) [look setCustomSpacing:NSStackViewSpacingUseDefault afterView:view];  // DPFillStack leaves more after a group.
    self.look = look;
    self.code = [self makeCodePage];
    self.code.hidden = YES;
    NSStackView *pages = DPColumn(@[ self.look, self.code ], 0);  // A stack lays out only the page that shows.
    for (NSView *page in pages.arrangedSubviews) [page.widthAnchor constraintEqualToAnchor:pages.widthAnchor].active = YES;

    NSView *root = [DPFlippedView new];  // Growing, it keeps what's in it where it was from the top, not the bottom, until laid out.
    pages.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:pages];
    self.width = [root.widthAnchor constraintEqualToConstant:DPLookWidth];
    [NSLayoutConstraint activateConstraints:@[
        [pages.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:DPEditorInset],
        [pages.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-DPEditorInset],
        [pages.topAnchor constraintEqualToAnchor:root.topAnchor constant:DPEditorInset],
        [pages.bottomAnchor constraintLessThanOrEqualToAnchor:root.bottomAnchor constant:-DPEditorInset],  // Stays put while the popover resizes.
        self.width,
    ]];
    return root;
}

- (void)showCode:(BOOL)code {
    self.look.hidden = code;
    self.code.hidden = !code;
    self.width.constant = code ? DPCodeWidth : DPLookWidth;
    [self fit];
}

- (void)showCodePage:(id)sender { [self showCode:YES]; }
- (void)showLookPage:(id)sender { [self showCode:NO]; }

@end
