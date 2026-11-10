#import "Patches/Boosts/Editor.h"

static DPBoostEditor *DPEditor;

@implementation DPBoostEditor (Popover)

// It closes itself like a transient popover, on a click outside it, Escape or Dia going to the background, but not while
// zapping, when the page's clicks are the picker's.
- (void)popoverDidShow:(NSNotification *)notification {
    __weak DPBoostEditor *weakSelf = self;
    self.clicks = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskKeyDown
                                                    handler:^NSEvent *(NSEvent *event) {
        DPBoostEditor *editor = weakSelf;
        if (!editor || editor.zapping) return event;
        if (event.window == editor.view.window) {
            if (event.type != NSEventTypeKeyDown || event.keyCode != 53) return event;  // 53: Escape.
            [editor.popover close];
            return nil;
        }
        if (event.type == NSEventTypeKeyDown) return event;
        NSView *button = DPBoostButtonIn(event.window);
        BOOL onButton = button && NSPointInRect([button convertPoint:event.locationInWindow fromView:nil], button.bounds);
        [editor.popover close];
        return onButton ? nil : event;  // The paintbrush closes it rather than opening it again.
    }];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(appDidResignActive:) name:NSApplicationDidResignActiveNotification object:nil];
}

- (void)appDidResignActive:(NSNotification *)notification {
    if (!self.zapping) [self.popover close];
}

- (void)popoverWillClose:(NSNotification *)notification {
    if (self.zapping) DPStopPicking(self.zapping);
    if (self.dirty) [self save];
}

// The popover holds its controller, which holds the popover. Let go once the close is done.
- (void)popoverDidClose:(NSNotification *)notification {
    if (self.clicks) [NSEvent removeMonitor:self.clicks];
    self.clicks = nil;
    [NSNotificationCenter.defaultCenter removeObserver:self name:NSApplicationDidResignActiveNotification object:nil];
    if (DPEditor == self) DPEditor = nil;
    dispatch_async(dispatch_get_main_queue(), ^{ self.popover = nil; });
}

@end

static NSWindow *DPBrowserWindow(void) {
    if (DPIsKind(NSApp.mainWindow, DPDiaWindow)) return NSApp.mainWindow;
    for (NSWindow *window in NSApp.orderedWindows)
        if (DPIsKind(window, DPDiaWindow) && window.visible) return window;
    return nil;
}

// Under the Boost button, else under the address field, else under the top of the window while the toolbar is hidden.
// A popover closes when the view it points at hides, and Dia hides the button and the field as the pointer leaves
// them, so it points at the window's content view where the button is.
static void DPShowPopover(NSPopover *popover, NSWindow *window) {
    NSView *content = window.contentView;
    NSView *target = DPBoostButtonIn(window) ?: DPFindView(content, ^BOOL(NSView *view) {
        return DPIsKind(view, DPDiaAddressField) && !view.isHiddenOrHasHiddenAncestor;
    });
    NSRect rect = target ? [content convertRect:target.bounds fromView:target]
                         : NSMakeRect(NSMidX(content.bounds), content.isFlipped ? 0 : NSMaxY(content.bounds) - 1, 1, 1);
    [popover showRelativeToRect:rect ofView:content preferredEdge:content.isFlipped ? NSRectEdgeMaxY : NSRectEdgeMinY];
}

void DPShowBoostEditor(NSString *domain) {
    NSWindow *window = DPBrowserWindow();
    if (!window) return NSBeep();
    if (DPEditor.popover.shown && [DPEditor.domain isEqual:domain]) return;
    DPCloseBoostEditor();
    DPEditor = [[DPBoostEditor alloc] initWithDomain:domain];
    DPEditor.browserWindow = window;
    DPEditor.popover.contentSize = DPEditor.view.fittingSize;
    DPShowPopover(DPEditor.popover, window);
}

void DPCloseBoostEditor(void) { [DPEditor.popover close]; }
