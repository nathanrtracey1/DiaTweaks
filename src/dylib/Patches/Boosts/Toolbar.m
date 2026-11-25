#import "Patches/Boosts/Boosts.h"

// The paintbrush (Button.m) goes among the address field's own buttons. Dia shows those while the field is hovered and
// hides them otherwise, so it follows the bookmark button.
#define DPAnchorLabels (@[ @"Bookmark this page", @"Site menu" ])
static char DPButtonKey;

static NSView *DPAnchor(NSView *field) {
    for (NSString *label in DPAnchorLabels) {
        NSView *found = DPFindView(field, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaFieldButton) && DPHasLabel(view, label); });
        if ([found.superview isKindOfClass:NSStackView.class]) return found;
    }
    return nil;
}

static void DPPlaceButton(NSView *field) {
    NSView *anchor = DPAnchor(field);
    DPBoostButton *button = DPGet(field, &DPButtonKey);
    if (!DPBoosts.on || !anchor) return [button removeFromSuperview];
    if (!button) DPSet(field, &DPButtonKey, button = [DPBoostButton new]);
    NSStackView *stack = (NSStackView *)anchor.superview;
    if (button.superview != stack) [stack insertArrangedSubview:button atIndex:[stack.arrangedSubviews indexOfObject:anchor]];
    if (button.hidden != anchor.hidden) button.hidden = anchor.hidden;
    [button sync];
}

static void DPField_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPField_layout, self);
    DPPlaceButton(self);
}

static NSView *DPFieldOf(NSView *view) {
    while (view && !DPIsKind(view, DPDiaAddressField)) view = view.superview;
    return view;
}

// Dia shows and hides its buttons as the pointer comes and goes, without laying the field out again.
static void DPFieldButton_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    DPCallOriginal(DPFieldButton_setHidden, self, hidden);
    NSView *field = DPFieldOf(self);
    DPBoostButton *button = field ? DPGet(field, &DPButtonKey) : nil;
    if (button.superview && DPAnchor(field) == self) button.hidden = hidden;
}

NSView *DPBoostButtonIn(NSWindow *window) {
    for (NSView *field in DPFindViews(DPDiaAddressField)) {
        DPBoostButton *button = DPGet(field, &DPButtonKey);
        if (button.window == window && !button.isHiddenOrHasHiddenAncestor) return button;
    }
    return nil;
}

void DPSyncBoostButtons(void) {
    for (NSView *field in DPFindViews(DPDiaAddressField)) DPPlaceButton(field);
}

NSString *DPVerifyBoostButtons(DPPatch *patch) {
    for (NSView *field in DPFindViews(DPDiaAddressField)) {
        if (!DPAnchor(field)) continue;
        DPBoostButton *button = DPGet(field, &DPButtonKey);
        if (patch->on != (button.superview != nil)) return patch->on ? @"no Boost button in the address field" : @"Boost button still in the address field";
    }
    return nil;
}

void DPInstallBoostButton(void) {
    DPHook(DPDiaAddressField, @selector(layout), (IMP)DPField_layout);
    DPHook(DPDiaFieldButton, @selector(setHidden:), (IMP)DPFieldButton_setHidden);
    // Each window's paintbrush shows the front tab's Boost, so they catch up as another window comes to the front.
    for (NSNotificationName name in @[ DPBoostsDidChangeNotification, NSWindowDidBecomeMainNotification ])
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *_) { DPSyncBoostButtons(); }];
}
