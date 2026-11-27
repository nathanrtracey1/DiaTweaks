#import "SidebarAddress.h"
#import "Patches/CompactCommandBar/CompactCommandBar.h"

// In a bar the sidebar's width, Go's label takes the room the address needs; its ↵ alone still says what it does.
static const CGFloat DPIconWidth = 32;
static char DPDiaWidthKey, DPLabelKey;

// Dia gives Go a minimum width that fits its label.
static NSLayoutConstraint *DPMinimumWidth(NSView *go) {
    for (NSLayoutConstraint *constraint in go.constraints)
        if (constraint.firstItem == go && constraint.firstAttribute == NSLayoutAttributeWidth && constraint.relation == NSLayoutRelationGreaterThanOrEqual)
            return constraint;
    return nil;
}

static NSTextField *DPLabel(NSView *go) {
    return (NSTextField *)DPFindView(go, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextField.class] && [(NSTextField *)view stringValue].length; });
}

static void DPShowAsIcon(NSView *go, BOOL icon) {
    NSLayoutConstraint *minimum = DPMinimumWidth(go);
    NSNumber *dia = DPGet(go, &DPDiaWidthKey);
    NSTextField *label = DPGet(go, &DPLabelKey) ?: DPLabel(go);
    if (icon) {
        if (!dia && minimum) DPSet(go, &DPDiaWidthKey, @(minimum.constant));
        DPSet(go, &DPLabelKey, label);
        if (minimum.constant != DPIconWidth) minimum.constant = DPIconWidth;
        if (!label.hidden) label.hidden = YES;
    } else if (dia) {
        minimum.constant = dia.doubleValue;
        label.hidden = NO;
        DPSet(go, &DPDiaWidthKey, nil);
        DPSet(go, &DPLabelKey, nil);
    }
}

static void DPGoButton_layout(NSView *self, SEL _cmd) {
    NSView *bar = self.superview;
    while (bar && !DPIsKind(bar, DPDiaCommandBar)) bar = bar.superview;
    if (bar && self == DPGoButton(DPCommandBarPart(bar, DPDiaCommandBarToolbar))) DPShowAsIcon(self, DPAnchoredPopover(bar) != nil);
    DPCallOriginal(DPGoButton_layout, self);
}

void DPInstallSidebarGo(void) {
    DPHook(DPDiaCommandBarButton, @selector(layout), (IMP)DPGoButton_layout);
}
