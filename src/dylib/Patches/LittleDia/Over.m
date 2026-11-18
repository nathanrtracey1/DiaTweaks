#import "LittleDia.h"
#import "Patches/HideToolbar/HideToolbar.h"

// A Little Dia opened from a tab sits over that tab's window: its toolbar hides, and a click on it closes Little Dia.
static NSMapTable<NSWindow *, NSWindow *> *gOver;  // Dia's window -> the Little Dia over it.

static NSArray<NSView *> *DPToolbars(NSWindow *window) {
    NSMutableArray<NSView *> *bars = [NSMutableArray array];
    for (NSView *pane in DPFindViews(DPDiaContentPane)) {
        NSView *bar = pane.window == window ? DPSubview(pane, DPDiaToolbar) : nil;
        if (!bar) continue;
        [bars addObject:bar];
        NSView *bookmarks = DPBookmarksUnder(pane, bar);
        if (bookmarks) [bars addObject:bookmarks];
    }
    return bars;
}

static void DPFadeToolbars(NSWindow *window, BOOL hidden) {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.2;
        for (NSView *bar in DPToolbars(window)) bar.animator.alphaValue = hidden ? 0 : 1;
    } completionHandler:^{
        if (hidden || !DPHideToolbar.on) return;
        for (NSView *pane in DPFindViews(DPDiaContentPane))
            if (pane.window == window) DPApplyToolbar(pane);  // Hide Toolbar decides again what shows.
    }];
}

BOOL DPLittleDiaIsOver(NSWindow *window) {
    NSWindow *little = window ? [gOver objectForKey:window] : nil;
    return little.visible;
}

static void DPUncover(NSWindow *little) {
    for (NSWindow *window in gOver.keyEnumerator.allObjects)
        if ([gOver objectForKey:window] == little) {
            [gOver removeObjectForKey:window];
            DPFadeToolbars(window, NO);
        }
}

void DPPutLittleDiaOver(NSWindow *little, NSWindow *window) {
    if (!little || !window || little == window) return;
    [gOver setObject:little forKey:window];
    DPFadeToolbars(window, YES);
}

void DPInstallLittleDiaOver(void) {
    gOver = [NSMapTable weakToWeakObjectsMapTable];
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowWillCloseNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        if (DPIsLittleDiaWindow(note.object)) DPUncover(note.object);
    }];
    NSEventMask clicks = NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskOtherMouseDown;
    [NSEvent addLocalMonitorForEventsMatchingMask:clicks handler:^NSEvent *(NSEvent *event) {
        if (!DPLittleDia.on || !DPLittleDiaIsOver(event.window)) return event;
        [[gOver objectForKey:event.window] performClose:nil];
        return nil;  // The click only closes it.
    }];
}
