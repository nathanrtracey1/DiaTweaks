#import "Patches/Peek/Peek.h"

static BOOL DPPeekCursorAllowed(NSView *view, NSPoint point) {
    if (!DPPeek.on || !DPPeekCardIn(view.window)) return YES;
    NSView *root = view.window.contentView;
    NSView *hit = [root hitTest:[root.superview convertPoint:point fromView:nil]];
    return hit == view || [hit isDescendantOf:view];
}

static BOOL DPWeb_shouldChangeCurrentCursor(NSView *self, SEL _cmd) {
    return DPCallOriginal(DPWeb_shouldChangeCurrentCursor, self) && DPPeekCursorAllowed(self, self.window.mouseLocationOutsideOfEventStream);
}

static void DPWeb_addCursorRect(NSView *self, SEL _cmd, NSRect rect, NSCursor *cursor) {
    DPPeekCard *peek = DPPeek.on ? DPPeekCardIn(self.window) : nil;
    if (!peek || [self isDescendantOf:peek]) return (void)DPCallOriginal(DPWeb_addCursorRect, self, rect, cursor);
    // Cursor rectangles, like Chromium's immediate cursor updates, ignore overlapping siblings.
    NSRect covered = NSIntersectionRect(rect, [self convertRect:peek.bounds fromView:peek]);
    if (NSIsEmptyRect(covered)) return (void)DPCallOriginal(DPWeb_addCursorRect, self, rect, cursor);
    NSRect exposed[] = {
        NSMakeRect(NSMinX(rect), NSMinY(rect), NSWidth(rect), NSMinY(covered) - NSMinY(rect)),
        NSMakeRect(NSMinX(rect), NSMaxY(covered), NSWidth(rect), NSMaxY(rect) - NSMaxY(covered)),
        NSMakeRect(NSMinX(rect), NSMinY(covered), NSMinX(covered) - NSMinX(rect), NSHeight(covered)),
        NSMakeRect(NSMaxX(covered), NSMinY(covered), NSMaxX(rect) - NSMaxX(covered), NSHeight(covered)),
    };
    for (NSUInteger i = 0; i < sizeof exposed / sizeof *exposed; i++)
        if (!NSIsEmptyRect(exposed[i])) DPCallOriginal(DPWeb_addCursorRect, self, exposed[i], cursor);
}

void DPPeekInstallCursor(void) {
    DPHook(DPDiaRenderWidget, @selector(shouldChangeCurrentCursor), (IMP)DPWeb_shouldChangeCurrentCursor);
    DPHook(DPDiaRenderWidget, @selector(addCursorRect:cursor:), (IMP)DPWeb_addCursorRect);
}
