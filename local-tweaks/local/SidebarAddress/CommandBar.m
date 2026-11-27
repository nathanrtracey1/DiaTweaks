#import "SidebarAddress.h"
#import "Patches/CompactCommandBar/CompactCommandBar.h"

static NSView *DPShownSidebarPill(NSWindow *window) {
    if (!window || DPSidebarAddressProgress() < 1) return nil;
    NSView *pill = DPFindView(window.contentView, ^BOOL(NSView *view) { return DPIsSidebarPill(view); });
    return pill.hiddenOrHasHiddenAncestor ? nil : pill;
}

static const CGFloat DPWidestBar = 640, DPWindowInset = 12, DPTextSlack = 8;

static BOOL DPIsAddressBar(NSView *popover) {
    return !DPIsFloatingChat(popover) && DPFindView(popover, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaCommandBar); });
}

NSView *DPAnchoredPopover(NSView *view) {
    NSView *popover = view;
    while (popover && !DPIsKind(popover, DPDiaPopover)) popover = popover.superview;
    return popover && DPShownSidebarPill(popover.window) && DPIsAddressBar(popover) ? popover : nil;
}

static char DPWantedKey;

// The bar's width with room for all of what's typed. What isn't text keeps its width, so it's measured from the bar
// once its input row is laid out for the bar's width; measured before, the two disagree and the width swings back and forth.
static void DPMeasureText(NSView *popover, NSView *bar) {
    NSView *input = DPFindView(bar, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaCommandBarInput); });
    NSView *box = DPFindView(input, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaCommandBarText); });
    NSTextView *text = (NSTextView *)DPFindView(box, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextView.class]; });
    if (!text) return;
    [input layoutSubtreeIfNeeded];
    CGFloat typed = ceil(text.attributedString.size.width) + 2 * text.textContainer.lineFragmentPadding + DPTextSlack;
    DPSet(popover, &DPWantedKey, @(NSWidth(bar.frame) - NSWidth(box.frame) + typed));
}

// The popover keeps a margin around Dia's panel for its shadow, and the panel lines up with the pill.
static CGFloat DPShadowMargin(NSView *popover) {
    NSView *panel = DPFindView(popover, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaAssistantPanel); });
    return panel ? NSMinX([popover convertRect:panel.bounds fromView:panel]) : 0;
}

// How far the middle of the bar's text row is below its top, so that row sits where the pill's text was.
static CGFloat DPInputMiddle(NSView *popover, NSRect anchor) {
    NSView *input = DPFindView(popover, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaCommandBarInput); });
    return input.superview.isFlipped ? NSMidY(input.frame) : NSHeight(anchor) / 2;
}

// Dia opens ⌘L's bar where the hidden toolbar's address was, across the top of the page; this opens it over the pill.
// It's as wide as the pill, or wider while what's typed needs it, up to DPWidestBar and the window's edge.
static NSRect DPOverPill(NSView *popover, NSRect frame) {
    NSView *parent = popover.superview, *pill = DPShownSidebarPill(popover.window);
    if (!pill || !parent || !DPIsAddressBar(popover)) return frame;
    NSRect anchor = [parent convertRect:pill.bounds fromView:pill];
    CGFloat margin = DPShadowMargin(popover), below = margin + DPInputMiddle(popover, anchor);
    CGFloat widest = MAX(NSWidth(anchor), MIN(DPWidestBar, NSWidth(parent.bounds) - NSMinX(anchor) - DPWindowInset));
    frame.size.width = MIN(MAX(NSWidth(anchor), [DPGet(popover, &DPWantedKey) doubleValue]), widest) + 2 * margin;
    frame.origin.x = NSMinX(anchor) - margin;
    frame.origin.y = parent.isFlipped ? NSMidY(anchor) - below : NSMidY(anchor) + below - NSHeight(frame);
    return frame;
}

static void DPSidebarPopover_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    DPCallOriginal(DPSidebarPopover_setFrame, self, DPOverPill(self, frame));
}

static void DPSidebarPopover_setFrameOrigin(NSView *self, SEL _cmd, NSPoint origin) {
    DPCallOriginal(DPSidebarPopover_setFrameOrigin, self, DPOverPill(self, (NSRect){origin, self.frame.size}).origin);
}

static void DPSidebarPopover_setFrameSize(NSView *self, SEL _cmd, NSSize size) {
    DPCallOriginal(DPSidebarPopover_setFrameSize, self, DPOverPill(self, (NSRect){self.frame.origin, size}).size);
}

// The bar and its input arrive after Dia first places the popover, and its margin and text row are only known then.
// Compact Command Bar trims the height of every size it's given, so a new width goes with the height it trimmed.
static void DPSidebarCommandBar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarCommandBar_layout, self);
    NSView *popover = DPAnchoredPopover(self);
    if (!popover) return;
    DPMeasureText(popover, self);
    NSRect over = DPOverPill(popover, popover.frame);
    if (NSWidth(over) != NSWidth(popover.frame) && DPMayAdjust(popover))
        [popover setFrameSize:NSMakeSize(NSWidth(over), NSHeight(popover.frame) + DPTrim(popover))];
    over = DPOverPill(popover, popover.frame);
    if (!NSEqualPoints(over.origin, popover.frame.origin) && DPMayAdjust(popover)) [popover setFrameOrigin:over.origin];
}

static void (*DPNSViewDidMoveToWindow)(id, SEL);

static void DPSidebarPopover_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    if (DPShownSidebarPill(self.window) && DPIsAddressBar(self)) {
        if (DPNSViewDidMoveToWindow) DPNSViewDidMoveToWindow(self, _cmd);
        return;
    }
    DPCallOriginal(DPSidebarPopover_viewDidMoveToWindow, self);
}

void DPInstallSidebarCommandBar(void) {
    DPInstallSidebarGo();
    DPNSViewDidMoveToWindow = (void (*)(id, SEL))[NSView instanceMethodForSelector:@selector(viewDidMoveToWindow)];
    [NSNotificationCenter.defaultCenter addObserverForName:NSTextDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSView *popover = DPAnchoredPopover(note.object);
        if (popover) DPFindView(popover, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaCommandBar); }).needsLayout = YES;
    }];
    DPHook(DPDiaPopover, @selector(viewDidMoveToWindow), (IMP)DPSidebarPopover_viewDidMoveToWindow);
    DPHook(DPDiaPopover, @selector(setFrame:), (IMP)DPSidebarPopover_setFrame);
    DPHook(DPDiaPopover, @selector(setFrameOrigin:), (IMP)DPSidebarPopover_setFrameOrigin);
    DPHook(DPDiaPopover, @selector(setFrameSize:), (IMP)DPSidebarPopover_setFrameSize);
    DPHook(DPDiaCommandBar, @selector(layout), (IMP)DPSidebarCommandBar_layout);
}
