#import "ProfileEmoji.h"

static NSString *const DPEmojisKey = @"profileEmojis";
NSString *const DPSymbolPrefix = @"symbol:";
// The gap is between what's drawn, so emoji and dots sit the same distance apart in any mix.
static const CGFloat DPSidebarEmojiSize = 13.5, DPSidebarEmojiWidth = 16, DPSidebarDotWidth = 6, DPSidebarGap = 10;
static NSUserDefaults *DPEmojiDefaults;
static char DPLabelKey;

// A symbol this macOS doesn't have counts as no icon, so Dia's dot shows instead of the saved name.
static NSString *DPEmoji(NSString *spaceID) {
    NSString *icon = DPProfileEmoji.on && spaceID ? DPSavedIcon(spaceID) : nil;
    if ([icon hasPrefix:DPSymbolPrefix] && !DPSymbolNamed([icon substringFromIndex:DPSymbolPrefix.length])) return nil;
    return icon;
}

// Keys are Swift SpaceIDs, which describe themselves as the ID.
static NSString *DPSpaceIDOf(NSView *view, NSDictionary *views) {
    for (id key in views) if (views[key] == view) return [key description];
    return nil;
}

static NSImage *DPSymbolImage(NSString *icon, CGFloat size) {
    if (![icon hasPrefix:DPSymbolPrefix]) return nil;
    NSImage *image = DPSymbolNamed([icon substringFromIndex:DPSymbolPrefix.length]);
    return [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:size weight:NSFontWeightSemibold]];
}

// An image view takes the mouse down an emoji's label passes on, which would stop clicks switching profiles.
@interface DPProfileSymbolView : NSImageView
@end

@implementation DPProfileSymbolView
- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

// Dia's item already reads the profile's name, which the symbol's own description, like "itunes u", would drown out.
- (BOOL)isAccessibilityElement {
    return NO;
}
@end

// One view per host, an image view for a symbol or a label for an emoji; nil kind removes it.
static NSView *DPIconView(NSView *host, Class kind) {
    NSView *view = DPGet(host, &DPLabelKey);
    if (view && ![view isKindOfClass:kind]) {
        [view removeFromSuperview];
        view = nil;
    }
    if (!view && kind) {
        view = kind == DPProfileSymbolView.class ? [DPProfileSymbolView new] : [NSTextField labelWithString:@""];
        [host addSubview:view];
    }
    DPSet(host, &DPLabelKey, view);
    return view;
}

// Symbols draw in the label color and dim the same way emoji do.
static void DPShowEmoji(NSView *host, NSView *dot, NSString *emoji, CGFloat size, CGFloat alpha) {
    NSImage *symbol = DPSymbolImage(emoji, size * 0.85);
    NSView *view = DPIconView(host, !emoji ? nil : symbol ? DPProfileSymbolView.class : NSTextField.class);
    dot.hidden = view != nil;
    if (!view) return;
    if (symbol) {
        NSImageView *image = (NSImageView *)view;
        image.image = symbol;
        image.contentTintColor = NSColor.labelColor;
        [image setFrameSize:symbol.size];
    } else {
        NSTextField *label = (NSTextField *)view;
        label.alignment = NSTextAlignmentCenter;
        label.stringValue = emoji;
        label.font = [NSFont systemFontOfSize:size];
        [label sizeToFit];
    }
    view.alphaValue = alpha;
    view.frame = (NSRect){ { round(NSMidX(host.bounds) - view.frame.size.width / 2), round(NSMidY(host.bounds) - view.frame.size.height / 2) }, view.frame.size };
}

static void DPShowSidebarItem(NSView *item) {
    NSString *emoji = DPEmoji(DPSpaceIDOf(item, DPSwiftValue(item.superview, @"itemViews")));
    BOOL selected = [DPSwiftValue(item, @"isSelected") boolValue];
    NSView *dot = DPSwiftValue(item, @"$__lazy_storage_$_dotView");
    [dot setFrameOrigin:NSMakePoint(round(NSMidX(item.bounds) - NSWidth(dot.frame) / 2), NSMinY(dot.frame))];
    DPShowEmoji(item, dot, emoji, DPSidebarEmojiSize, selected ? 1 : 0.45);
}

static CGFloat DPSidebarItemWidth(NSView *item, NSDictionary *views) {
    return (DPEmoji(DPSpaceIDOf(item, views)) ? DPSidebarEmojiWidth : DPSidebarDotWidth) + DPSidebarGap;
}

// Dia packs items 12 points apart, which crowds emoji, so each item gets its own width and the row stays centered.
// Dia also places items outside layout, such as after switching profiles.
static void DPSidebarItem_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    NSView *switcher = self.superview;
    NSDictionary *views = DPSwiftValue(switcher, @"itemViews");
    BOOL anyEmoji = NO;
    for (id key in views) anyEmoji = anyEmoji || DPEmoji([key description]);
    if (anyEmoji && NSWidth(frame) > 0 && NSWidth(frame) < DPSidebarDotWidth + DPSidebarGap) {
        CGFloat middle = NSMidX(switcher.bounds);
        NSInteger index = lround((NSMinX(frame) - (middle - views.count * NSWidth(frame) / 2)) / NSWidth(frame));
        NSMutableArray<NSView *> *row = [[views.allValues filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != %@", self]] mutableCopy];
        [row sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) { return [@(NSMidX(a.frame)) compare:@(NSMidX(b.frame))]; }];
        [row insertObject:self atIndex:MIN(MAX(index, 0), (NSInteger)row.count)];
        CGFloat total = 0, x = 0;
        for (NSView *item in row) total += DPSidebarItemWidth(item, views);
        for (NSView *item in row) {
            if (item == self) break;
            x += DPSidebarItemWidth(item, views);
        }
        frame = NSMakeRect(round(middle - total / 2 + x), NSMinY(frame), DPSidebarItemWidth(self, views), NSHeight(frame));
    }
    DPCallOriginal(DPSidebarItem_setFrame, self, frame);
}

static void DPSidebarItem_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarItem_layout, self);
    DPShowSidebarItem(self);
}

static void DPSidebarItem_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarItem_updateLayer, self);
    DPShowSidebarItem(self);
}

static void DPTopDot_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTopDot_layout, self);
    NSView *indicator = self.superview;
    NSString *spaceID = DPSpaceIDOf(self, DPSwiftValue(indicator, @"dotViews"));
    BOOL focused = [[DPSwiftValue(indicator, @"focusedSpaceID") description] isEqual:spaceID];
    DPShowEmoji(self, self.subviews.firstObject, DPEmoji(spaceID), 8, focused ? 1 : 0.45);
}

static void DPRefresh(DPPatch *patch) {
    for (NSString *name in @[ @DPDiaSpaceSwitcher, @DPDiaSpaceSwitcherItem, @DPDiaPageIndicatorDot ])
        for (NSView *view in DPFindViews(name.UTF8String)) view.needsLayout = YES;
}

NSString *DPSavedIcon(NSString *spaceID) {
    return [DPEmojiDefaults dictionaryForKey:DPEmojisKey][spaceID];
}

void DPSaveIcon(NSString *spaceID, NSString *icon) {
    NSMutableDictionary *icons = [[DPEmojiDefaults dictionaryForKey:DPEmojisKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    icons[spaceID] = icon;
    [DPEmojiDefaults setObject:icons forKey:DPEmojisKey];
    DPRefresh(&DPProfileEmoji);
}

static void DPProfilePane_viewDidLoad(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPProfilePane_viewDidLoad, self);
    if (DPProfileEmoji.on) DPAddEmojiRow(self);
}

static void DPInstallProfileEmoji(void) {
    DPEmojiDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    DPHookClass(objc_getClass(DPDiaSpaceSwitcherItem), @selector(setFrame:), (IMP)DPSidebarItem_setFrame);
    DPHook(DPDiaSpaceSwitcherItem, @selector(layout), (IMP)DPSidebarItem_layout);
    DPHook(DPDiaSpaceSwitcherItem, @selector(updateLayer), (IMP)DPSidebarItem_updateLayer);
    DPHook(DPDiaPageIndicatorDot, @selector(layout), (IMP)DPTopDot_layout);
    DPHook(DPDiaProfilePane, @selector(viewDidLoad), (IMP)DPProfilePane_viewDidLoad);
}

DP_PATCH(DPProfileEmoji) {
    .key = @"profileEmoji",
    .order = 78,
    .defaultOn = YES,
    .title = @"Profile Emoji",
    .detail = @"Show an emoji or a symbol in place of each profile’s dot in the profile switcher. Choose them in Settings › Profiles.",
    .symbol = @"emoji.face.grinning.inverse face.smiling.inverse",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaSpaceSwitcher, DPDiaSpaceSwitcherItem, DPDiaPageIndicatorDot, DPDiaProfilePane, DPDiaSettingsFormGroup),
    .install = DPInstallProfileEmoji,
    .apply = DPRefresh,
};
