#import "Patches/LittleDia/Route.m"

// Stand-ins for what Route.m asks of the rest of Little Dia, and for Dia's content pane.
DPPatch DPLittleDia, DPLittleDiaFollowRules;
NSSize DPLittleDiaSize(void) { return NSZeroSize; }
BOOL DPSendToLittleDia(NSDictionary *request) { return NO; }
void DPExpectLittleDiaWindow(NSRect frame, NSDictionary *noted, void (^missed)(void), void (^claimed)(NSWindow *window)) {}
void DPLinkArrived(void) {}
NSDictionary *DPNoteStackForLink(void) { return nil; }
void DPBringBackPutAway(NSWindow *little) {}
BOOL DPLittleDiaStarting(void) { return NO; }
void DPPutLittleDiaOver(NSWindow *little, NSWindow *window) {}
void DPEditLittleDiaAddress(NSWindow *window) {}

static BOOL gTabsAtTop;
BOOL DPTabsAtTop(NSWindow *window) { return gTabsAtTop; }

@interface _TtC11ContentPane15ContentPaneView : NSView
@end
@implementation _TtC11ContentPane15ContentPaneView
@end

static int failures;

// The window is far off screen, so its whole frame counts. Rects are given from the window's bottom left corner.
static void frame(NSString *what, BOOL tabsAtTop, NSSize size, NSRect pane, NSRect want) {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:(NSRect){{-30000, -30000}, size} styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.alphaValue = 0;
    window.ignoresMouseEvents = YES;
    [window.contentView addSubview:[[NSClassFromString(@(DPDiaContentPane)) alloc] initWithFrame:pane]];
    [window orderFront:nil];
    gTabsAtTop = tabsAtTop;
    NSRect got = DPOverWindowFrame(window);
    got.origin.x -= NSMinX(window.frame);
    got.origin.y -= NSMinY(window.frame);
    if (!NSEqualRects(got, want)) printf("FAIL %s: %s, want %s\n", what.UTF8String, NSStringFromRect(got).UTF8String, NSStringFromRect(want).UTF8String), failures++;
    [window orderOut:nil];
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSSize size = NSMakeSize(1200, 800);
        // Sidebar: 12 pt in from the window's top and bottom, whatever sits between the window and the page.
        frame(@"sidebar", NO, size, NSMakeRect(190, 0, 1010, 800), NSMakeRect(291, 12, 808, 776));
        frame(@"sidebar, padded page", NO, size, NSMakeRect(196, 6, 998, 788), NSMakeRect(296, 12, 798, 776));
        // Tabs at the top: 12 pt in from the page's top, which is 40 pt below the window's.
        frame(@"top", YES, size, NSMakeRect(0, 0, 1200, 760), NSMakeRect(120, 12, 960, 736));
        frame(@"top, tabs hidden", YES, size, NSMakeRect(0, 0, 1200, 800), NSMakeRect(120, 12, 960, 776));
        // Too short for the popup: the floor holds and it stays centred.
        frame(@"short", NO, NSMakeSize(1200, 300), NSMakeRect(190, 0, 1010, 300), NSMakeRect(291, -30, 808, 360));
        frame(@"short, tabs at the top", YES, NSMakeSize(1200, 300), NSMakeRect(0, 0, 1200, 260), NSMakeRect(120, -50, 960, 360));
    }
    if (failures) return 1;
    puts("PASS: over-the-page frame in both layouts");
    return 0;
}
