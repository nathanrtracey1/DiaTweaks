#import "ProfileEmoji.h"

static NSString *const DPEmojisKey = @"profileEmojis";
<<<<<<< HEAD
static const CGFloat DPSidebarEmojiSize = 13.5, DPSidebarEmojiWidth = 16, DPSidebarDotWidth = 6, DPSidebarGap = 10;
static NSHashTable<NSViewController *> *DPProfilePanes;
static char DPLabelKey, DPRowKey;
=======
NSString *const DPSymbolPrefix = @"symbol:";
// The gap is between what's drawn, so emoji and dots sit the same distance apart in any mix.
static const CGFloat DPSidebarEmojiSize = 13.5, DPSidebarEmojiWidth = 16, DPSidebarDotWidth = 6, DPSidebarGap = 10;
static NSUserDefaults *DPEmojiDefaults;
static char DPLabelKey;
>>>>>>> pr-310-latest

// A symbol this macOS doesn't have counts as no icon, so Dia's dot shows instead of the saved name.
static NSString *DPEmoji(NSString *spaceID) {
<<<<<<< HEAD
    return DPProfileEmoji.on && spaceID ? [DPSettingsDefaults() dictionaryForKey:DPEmojisKey][spaceID] : nil;
=======
    NSString *icon = DPProfileEmoji.on && spaceID ? DPSavedIcon(spaceID) : nil;
    if ([icon hasPrefix:DPSymbolPrefix] && !DPSymbolNamed([icon substringFromIndex:DPSymbolPrefix.length])) return nil;
    return icon;
>>>>>>> pr-310-latest
}

static NSString *DPSpaceIDOf(NSView *view, NSDictionary *views) {
    for (id key in views) if (views[key] == view) return [key description];
    return nil;
}

<<<<<<< HEAD
static BOOL DPAnyEmoji(NSDictionary *views, NSDictionary *emojis) {
    for (id key in views) if (emojis[[key description]]) return YES;
    return NO;
}

static BOOL DPAnySidebarEmoji(NSView *switcher) {
    if (!DPProfileEmoji.on || !switcher) return NO;
    NSDictionary *emojis = [DPSettingsDefaults() dictionaryForKey:DPEmojisKey];
    return emojis.count && DPAnyEmoji(DPSwiftValue(switcher, @"itemViews"), emojis);
}

static void DPShowEmoji(NSView *host, NSView *dot, NSString *emoji, CGFloat size, CGFloat alpha) {
    NSTextField *label = DPGet(host, &DPLabelKey);
    if (!emoji) {
        if (!label) return;
        if (dot.hidden) dot.hidden = NO;
        [label removeFromSuperview];
        DPSet(host, &DPLabelKey, nil);
        return;
    }
    if (!dot.hidden) dot.hidden = YES;
    BOOL resized = !label;
    if (!label) {
        label = [NSTextField labelWithString:@""];
=======
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
>>>>>>> pr-310-latest
        label.alignment = NSTextAlignmentCenter;
        label.stringValue = emoji;
        label.font = [NSFont systemFontOfSize:size];
        [label sizeToFit];
    }
<<<<<<< HEAD
    if (![label.stringValue isEqual:emoji]) {
        label.stringValue = emoji;
        resized = YES;
    }
    if (fabs(label.font.pointSize - size) > 0.01) {
        label.font = [NSFont systemFontOfSize:size];
        resized = YES;
    }
    if (fabs(label.alphaValue - alpha) > 0.001) label.alphaValue = alpha;
    if (resized) [label sizeToFit];
    NSRect target = (NSRect){ { round(NSMidX(host.bounds) - label.frame.size.width / 2), round(NSMidY(host.bounds) - label.frame.size.height / 2) }, label.frame.size };
    if (!NSEqualRects(label.frame, target)) label.frame = target;
=======
    view.alphaValue = alpha;
    view.frame = (NSRect){ { round(NSMidX(host.bounds) - view.frame.size.width / 2), round(NSMidY(host.bounds) - view.frame.size.height / 2) }, view.frame.size };
>>>>>>> pr-310-latest
}

static void DPShowSidebarItem(NSView *item) {
    NSTextField *existing = DPGet(item, &DPLabelKey);
    if (!DPProfileEmoji.on && !existing) return;
    NSString *emoji = DPEmoji(DPSpaceIDOf(item, DPSwiftValue(item.superview, @"itemViews")));
    BOOL any = emoji || DPAnySidebarEmoji(item.superview);
    if (!existing && !any) return;
    BOOL selected = [DPSwiftValue(item, @"isSelected") boolValue];
    NSView *dot = DPSwiftValue(item, @"$__lazy_storage_$_dotView");
    if (dot && !emoji) {
        NSPoint origin = NSMakePoint(round(NSMidX(item.bounds) - NSWidth(dot.frame) / 2), NSMinY(dot.frame));
        if (!NSEqualPoints(dot.frame.origin, origin)) [dot setFrameOrigin:origin];
    }
    DPShowEmoji(item, dot, emoji, DPSidebarEmojiSize, selected ? 1 : 0.45);
}

static CGFloat DPSidebarItemWidth(NSView *item, NSDictionary *views, NSDictionary *emojis) {
    NSString *spaceID = DPSpaceIDOf(item, views);
    return (spaceID && emojis[spaceID] ? DPSidebarEmojiWidth : DPSidebarDotWidth) + DPSidebarGap;
}

static void DPSidebarItem_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    if (!DPProfileEmoji.on || NSWidth(frame) <= 0 || NSWidth(frame) >= DPSidebarDotWidth + DPSidebarGap)
        return DPCallOriginal(DPSidebarItem_setFrame, self, frame);
    NSDictionary *emojis = [DPSettingsDefaults() dictionaryForKey:DPEmojisKey];
    if (!emojis.count) return DPCallOriginal(DPSidebarItem_setFrame, self, frame);
    NSView *switcher = self.superview;
    NSDictionary *views = DPSwiftValue(switcher, @"itemViews");
    if (DPAnyEmoji(views, emojis)) {
        CGFloat middle = NSMidX(switcher.bounds);
        NSInteger index = lround((NSMinX(frame) - (middle - views.count * NSWidth(frame) / 2)) / NSWidth(frame));
        NSMutableArray<NSView *> *row = [NSMutableArray arrayWithCapacity:views.count + 1];
        for (NSView *item in views.allValues) if (item != self) [row addObject:item];
        [row sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
            CGFloat left = NSMidX(a.frame), right = NSMidX(b.frame);
            if (left < right) return NSOrderedAscending;
            return left > right ? NSOrderedDescending : NSOrderedSame;
        }];
        [row insertObject:self atIndex:MIN(MAX(index, 0), (NSInteger)row.count)];
        CGFloat total = 0, x = 0;
        for (NSView *item in row) total += DPSidebarItemWidth(item, views, emojis);
        for (NSView *item in row) {
            if (item == self) break;
            x += DPSidebarItemWidth(item, views, emojis);
        }
        frame = NSMakeRect(round(middle - total / 2 + x), NSMinY(frame), DPSidebarItemWidth(self, views, emojis), NSHeight(frame));
    }
    DPCallOriginal(DPSidebarItem_setFrame, self, frame);
}

static void DPSidebarItem_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarItem_layout, self);
    DPShowSidebarItem(self);
}

static void DPSidebarItem_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarItem_updateLayer, self);
    NSTextField *label = DPGet(self, &DPLabelKey);
    if (!DPProfileEmoji.on && !label) return;
    NSString *emoji = DPEmoji(DPSpaceIDOf(self, DPSwiftValue(self.superview, @"itemViews")));
    if ((emoji != nil) != (label != nil)) {
        __weak NSView *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSView *item = weakSelf;
            if (DPProfileEmoji.on || DPGet(item, &DPLabelKey)) item.needsLayout = YES;
        });
        return;
    }
    if (!label) return;
    CGFloat alpha = [DPSwiftValue(self, @"isSelected") boolValue] ? 1 : 0.45;
    if (fabs(label.alphaValue - alpha) > 0.001) label.alphaValue = alpha;
}

static void DPTopDot_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTopDot_layout, self);
    NSView *label = DPGet(self, &DPLabelKey);
    if (!DPProfileEmoji.on && !label) return;
    NSView *indicator = self.superview, *dot = nil;
    for (NSView *sub in self.subviews) if (sub != label) { dot = sub; break; }
    NSString *spaceID = DPSpaceIDOf(self, DPSwiftValue(indicator, @"dotViews"));
    BOOL focused = [[DPSwiftValue(indicator, @"focusedSpaceID") description] isEqual:spaceID];
    DPShowEmoji(self, dot, DPEmoji(spaceID), 8, focused ? 1 : 0.45);
}

static void DPRefresh(void) {
    for (const char *const *name = DPClasses(DPDiaSpaceSwitcher, DPDiaSpaceSwitcherItem, DPDiaPageIndicatorDot); *name; name++)
        for (NSView *view in DPFindAllViews(*name)) view.needsLayout = YES;
}

NSString *DPSavedIcon(NSString *spaceID) {
    return [DPSettingsDefaults() dictionaryForKey:DPEmojisKey][spaceID];
}

void DPSaveIcon(NSString *spaceID, NSString *icon) {
    NSMutableDictionary *icons = [[DPSettingsDefaults() dictionaryForKey:DPEmojisKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    icons[spaceID] = icon;
    [DPSettingsDefaults() setObject:icons forKey:DPEmojisKey];
    DPRefresh();
}

static void DPApplyProfileEmoji(DPPatch *patch) {
    for (NSViewController *pane in DPProfilePanes.allObjects) {
        if (patch->on) DPAddEmojiRow(pane);
        else DPRemoveEmojiRow(pane);
    }
    DPRefresh();
}

static void DPProfilePane_viewDidLoad(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPProfilePane_viewDidLoad, self);
    [DPProfilePanes addObject:self];
    if (DPProfileEmoji.on) DPAddEmojiRow(self);
}

static void DPInstallProfileEmoji(void) {
    DPProfilePanes = [NSHashTable weakObjectsHashTable];
    DPHookClass(objc_getClass(DPDiaSpaceSwitcherItem), @selector(setFrame:), (IMP)DPSidebarItem_setFrame);
    DPHook(DPDiaSpaceSwitcherItem, @selector(layout), (IMP)DPSidebarItem_layout);
    DPHook(DPDiaSpaceSwitcherItem, @selector(updateLayer), (IMP)DPSidebarItem_updateLayer);
    DPHook(DPDiaPageIndicatorDot, @selector(layout), (IMP)DPTopDot_layout);
    DPHook(DPDiaProfilePane, @selector(viewDidLoad), (IMP)DPProfilePane_viewDidLoad);
}

DP_PATCH(DPProfileEmoji) {
    .key = @"profileEmoji",
    .order = 84,
    .defaultOn = YES,
    .title = @"Profile Emoji",
    .detail = @"Show an emoji or a symbol in place of each profile’s dot in the profile switcher. Choose them in Settings › Profiles.",
    .symbol = @"emoji.face.grinning.inverse face.smiling.inverse",
    .tint = @"systemRedColor",
    .section = @"Profiles",
    .classes = DPClasses(DPDiaSpaceSwitcher, DPDiaSpaceSwitcherItem, DPDiaPageIndicatorDot, DPDiaProfilePane, DPDiaSettingsFormGroup),
    .install = DPInstallProfileEmoji,
    .apply = DPApplyProfileEmoji,
};
