#import "Patches/Boosts/Editor.h"

static const CGFloat DPZapListHeight = 180;
static char DPZapKey;  // The zap a row's button shows again.

@implementation DPBoostEditor (ZapList)

// Arc's Zap button, then what it hid, newest first, each under a line like a group's. The list scrolls past
// DPZapListHeight, so the popover stops growing there.
- (NSView *)makeZapGroup {
    self.zapHow = DPBoostTileLabel(@"");
    self.bolt = DPSymbol(@"bolt.fill", 13, NSColor.labelColor);
    __weak DPBoostEditor *weakSelf = self;
    NSView *zapRow = DPLinkRow(DPRow(self.zapHow, self.bolt), @"Zap", ^{ [weakSelf zap:nil]; });

    self.zapRows = [NSStackView new];
    self.zapRows.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.zapRows.spacing = 0;
    DPFlippedView *list = [DPFlippedView new];
    self.zapRows.translatesAutoresizingMaskIntoConstraints = list.translatesAutoresizingMaskIntoConstraints = NO;
    [list addSubview:self.zapRows];
    self.zapScroll = [NSScrollView new];
    self.zapScroll.drawsBackground = NO;
    self.zapScroll.hasVerticalScroller = YES;
    self.zapScroll.autohidesScrollers = YES;
    self.zapScroll.documentView = list;
    // Just under the rows' own height, or past DPZapListHeight Auto Layout may as well squash the last rows as scroll.
    NSLayoutConstraint *fit = [self.zapScroll.heightAnchor constraintEqualToAnchor:list.heightAnchor];
    fit.priority = NSLayoutPriorityDefaultHigh - 1;
    [NSLayoutConstraint activateConstraints:@[
        [self.zapRows.leadingAnchor constraintEqualToAnchor:list.leadingAnchor], [self.zapRows.trailingAnchor constraintEqualToAnchor:list.trailingAnchor],
        [self.zapRows.topAnchor constraintEqualToAnchor:list.topAnchor], [self.zapRows.bottomAnchor constraintEqualToAnchor:list.bottomAnchor],
        [list.widthAnchor constraintEqualToAnchor:self.zapScroll.contentView.widthAnchor],
        [list.topAnchor constraintEqualToAnchor:self.zapScroll.contentView.topAnchor],
        fit, [self.zapScroll.heightAnchor constraintLessThanOrEqualToConstant:DPZapListHeight],
    ]];
    for (NSDictionary *zap in self.zaps) [self addZapRow:zap animated:NO];
    [self showZapping];

    NSStackView *column = DPColumn(@[ zapRow, self.zapScroll ], 0);
    for (NSView *view in column.arrangedSubviews) [view.widthAnchor constraintEqualToAnchor:column.widthAnchor].active = YES;
    return DPGroup(@[ column ]);
}

- (void)showZapping {
    self.zapHow.stringValue = self.zapping ? @"Done" : @"Zap";
    self.bolt.contentTintColor = self.zapping ? NSColor.systemPinkColor : NSColor.labelColor;
}

// One thing hidden, under a line like a group's.
- (void)addZapRow:(NSDictionary *)zap animated:(BOOL)animated {
    NSButton *show = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"minus.circle" accessibilityDescription:@"Show It Again"] target:self action:@selector(unzap:)];
    show.bordered = NO;
    show.contentTintColor = NSColor.secondaryLabelColor;
    DPSet(show, &DPZapKey, zap);
    NSView *row = DPDrawerRow(DPRow(DPBoostLabel(zap[@"label"]), show), !animated);
    [self.zapRows insertArrangedSubview:row atIndex:0];
    [row.widthAnchor constraintEqualToAnchor:self.zapRows.widthAnchor].active = YES;
    if (animated) [self open:YES row:row done:nil];
}

- (void)unzap:(NSButton *)sender {
    NSUInteger index = [self.zaps indexOfObjectIdenticalTo:DPGet(sender, &DPZapKey)];
    if (index == NSNotFound) return;
    [self.zaps removeObjectAtIndex:index];
    [self save];
    NSView *row = sender.superview.superview;
    sender.enabled = NO;
    [self open:NO row:row done:^{ [row removeFromSuperview]; }];
}

@end
