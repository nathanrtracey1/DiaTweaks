#import "Toolbar.h"

static char DPCopyPeekTimerKey;

BOOL DPSidebarToolbarIsPeeking(NSView *pane) {
    return DPHideToolbar.on && DPGet(pane, &DPCopyPeekTimerKey) != nil;
}

BOOL DPSidebarUsesToolbarCopyFeedback(NSWindow *window) {
    if (!DPHideToolbar.on) return NO;
    NSView *first = nil;
    NSResponder *responder = window.firstResponder;
    for (NSView *pane in DPPanes) {
        if (pane.window != window || pane.hiddenOrHasHiddenAncestor) continue;
        if ([responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:pane])
            return DPSidebarReplacesToolbar(pane) && [DPToolbarHover forPane:pane] != nil;
        first = first ?: pane;
    }
    return first && DPSidebarReplacesToolbar(first) && [DPToolbarHover forPane:first] != nil;
}

static void DPSidebarEndCopyPeek(NSView *pane) {
    if (!pane) return;
    NSTimer *timer = DPGet(pane, &DPCopyPeekTimerKey);
    [timer invalidate];
    DPSet(pane, &DPCopyPeekTimerKey, nil);
}

void DPSidebarStopToolbarHover(DPToolbarHover *hover) {
    if (!hover) return;
    [hover.animation invalidate]; [hover.hideTimer invalidate];
    [hover.inPlaceAnimation invalidate];
    hover.animation = hover.hideTimer = hover.inPlaceAnimation = nil;
    // These are the implementation's own state flags; avoid setters that start timers.
    for (NSString *name in @[@"_revealed", @"_inPlace"])
        if (DPIvar(hover, name.UTF8String)) *(BOOL *)DPIvar(hover, name.UTF8String) = NO;
    hover.progress = hover.inPlaceProgress = 0;
    if (hover.tracking) [hover.pane removeTrackingArea:hover.tracking];
    hover.tracking = nil;
}

static void DPSidebarHover_update(DPToolbarHover *self, SEL _cmd, NSView *bar, NSView *bookmarks) {
    DPCallOriginal(DPSidebarHover_update, self, bar, bookmarks);
    if (DPSidebarReplacesToolbar(self.pane)) DPSidebarStopToolbarHover(self);
}

static void DPSidebarHover_reset(DPToolbarHover *self, SEL _cmd) {
    DPSidebarEndCopyPeek(self.pane);
    DPSidebarRestoreToolbar(self.pane);
    DPCallOriginal(DPSidebarHover_reset, self);
    DPSidebarApplyToolbar(self.pane);
}

void DPSidebarInstallToolbarHover(void) {
    DPHookClass(DPToolbarHover.class, @selector(updateForBar:bookmarks:), (IMP)DPSidebarHover_update);
    DPHookClass(DPToolbarHover.class, NSSelectorFromString(@"reset"), (IMP)DPSidebarHover_reset);
}
