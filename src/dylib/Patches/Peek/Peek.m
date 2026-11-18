#import "Patches/Peek/Peek.h"
#import "Commands/GroupTabs/GroupTabs.h"
#import "Patches/LittleDia/LittleDia.h"

static NSURL *DPPeekHovered;
static __weak id DPPeekHoveredPage, DPPeekHoveredDelegate;
static NSUInteger DPPeekLookAheadTurn;
static NSString *DPPeekLink, *DPPeekPressed;  // The link under the pointer, as Dia's status text says; it leaves "http://" out, so it is kept without a scheme.
static __weak id DPPeekLinkPage, DPPeekPressedPage;
static NSTimeInterval DPPeekPressedAt;

static BOOL DPPeekWanted(NSInteger disposition) {
    BOOL elsewhere = disposition == DPForegroundTab || disposition == DPBackgroundTab || disposition == DPPopup || disposition == DPNewWindow;
    NSEventModifierFlags mods = NSEvent.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask & ~(NSEventModifierFlagCapsLock | NSEventModifierFlagNumericPad | NSEventModifierFlagFunction);
    return DPPeek.on && !DPPeekGiving && elsewhere && mods == NSEventModifierFlagShift;  // Exactly Shift: ⌘⇧-click and ⌥⇧-click keep their meaning.
}

// The page clears the status as a click starts, before Dia is asked what to do with it, so the link under the pointer at mouse-down counts.
BOOL DPPeekOverLink(id page, NSURL *url) {
    NSString *key = url ? DPPeekLinkKey(url.absoluteString) : nil;
    if (!page || !key) return NO;
    if (page == DPPeekLinkPage && [key isEqual:DPPeekLink]) return YES;
    return page == DPPeekPressedPage && [key isEqual:DPPeekPressed] && NSProcessInfo.processInfo.systemUptime - DPPeekPressedAt < 2;
}

BOOL DPPeekIsWeb(NSURL *url) { return [url isKindOfClass:NSURL.class] && [@[ @"http", @"https" ] containsObject:url.scheme.lowercaseString]; }

static void DPPeekOpenLater(id delegate, id source, NSURL *url) {
    DPPeekLookAheadTurn++;  // The link opens now; a look-ahead still waiting would load it again.
    NSWindow *window = NSApp.keyWindow;
    NSPoint origin = NSEvent.mouseLocation;
    dispatch_async(dispatch_get_main_queue(), ^{ DPPeekOpen(window, url, origin, delegate, source); });
}

static void DPWebContent_didCreate(id self, SEL _cmd, id webContents, id newWebContent, NSURL *url, NSInteger disposition) {
    if (!DPPeekWanted(disposition) || !(DPPeekShows(webContents) || (DPPeekIsWeb(url) && DPPeekCanOpen(webContents))))
        return (void)DPCallOriginal(DPWebContent_didCreate, self, webContents, newWebContent, url, disposition);
    DPCallOriginal(DPWebContent_didCreate, self, webContents, newWebContent, url, (NSInteger)DPIgnoreAction);
    if (DPPeekShows(webContents)) return DPPeekLoad(webContents, url);
    DPPeekOpenLater(self, webContents, url);
}

@interface DPStayingAction : NSProxy
@property (nonatomic, strong) id action;
@end

@implementation DPStayingAction
- (NSInteger)navigationDisposition { return DPCurrentTab; }
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector { return [self.action methodSignatureForSelector:selector]; }
- (void)forwardInvocation:(NSInvocation *)invocation { [invocation invokeWithTarget:self.action]; }
@end

// Dia leaves a pinned row's links in its tab, so a plain click that goes to another site is Peek's to take.
static BOOL DPPeekLeavesPinnedRow(id webContents, id action, NSInteger disposition, NSInteger policy) {
    NSEventModifierFlags mods = NSEvent.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask & ~(NSEventModifierFlagCapsLock | NSEventModifierFlagNumericPad | NSEventModifierFlagFunction);
    BOOL stays = disposition == DPCurrentTab || disposition == DPForegroundTab;
    NSInteger type = [[action valueForKey:@"navigationType"] integerValue];
    // Dia reports a click on a target=_blank link as an "other" navigation (4) into a new tab, a click on any other link as a link activation (0).
    BOOL clicked = type == 0 || (type == 4 && disposition == DPForegroundTab);
    if (mods || !stays || !clicked || (policy != DPCurrentTab && policy != DPForegroundTab)) return NO;
    NSString *from = DPDomainKey([[(NSObject *)webContents valueForKey:@"url"] absoluteString]), *to = DPDomainKey([[action valueForKey:@"url"] absoluteString]);
    if (!from || !to || [DPRegistrableDomain(from) isEqual:DPRegistrableDomain(to)]) return NO;
    return !DPPeekShows(webContents) && DPPeekInPinnedRow(NSApp.keyWindow, webContents);
}

static NSInteger DPWebContent_decidePolicy(id self, SEL _cmd, id webContents, id action) {
    NSInteger disposition = [[action valueForKey:@"navigationDisposition"] integerValue];
    if (!DPPeekWanted(disposition)) {
        NSInteger policy = DPCallOriginal(DPWebContent_decidePolicy, self, webContents, action);
        BOOL peeks = DPPeek.on && DPPeekPinnedLinks.on, little = DPLittleDia.on && DPLittleDiaTabLinks.on;
        if (!peeks && !little) return policy;
        NSURL *url = [action valueForKey:@"url"];
        // A new tab asked for by a page's own script has no link under the pointer, and would lose its opener in Little Dia.
        BOOL clicked = disposition != DPForegroundTab || DPPeekOverLink(webContents, url);
        // Finding a pinned row builds a menu. Without Peek's pinned links, Little Dia needs it only for a clicked link that Dia keeps in the tab.
        BOOL leaves = (peeks || (clicked && policy == DPCurrentTab)) && DPPeekLeavesPinnedRow(webContents, action, disposition, policy);
        if (!leaves && policy == DPForegroundTab) {
            // Ask Dia as if the link stayed in the tab: only an icon-only pinned tab turns that into a new tab.
            leaves = disposition == DPCurrentTab;
            if (disposition == DPForegroundTab && !(NSEvent.modifierFlags & NSEventModifierFlagCommand)) {
                DPStayingAction *staying = [DPStayingAction alloc];
                staying.action = action;
                leaves = DPCallOriginal(DPWebContent_decidePolicy, self, webContents, staying) == DPForegroundTab;
            }
        }
        if ((policy == DPForegroundTab || leaves) && clicked && DPLittleDiaTakesTabLink(webContents, url, leaves)) return DPIgnoreAction;
        if (!peeks || !leaves || !DPPeekIsWeb(url) || !DPPeekCanOpen(webContents)) return policy;
        DPPeekOpenLater(self, webContents, url);
        return DPIgnoreAction;
    }
    if (DPPeekShows(webContents)) return DPCurrentTab;
    NSURL *url = [action valueForKey:@"url"];
    if (!DPPeekIsWeb(url) || !DPPeekCanOpen(webContents)) return DPCallOriginal(DPWebContent_decidePolicy, self, webContents, action);
    DPPeekOpenLater(self, webContents, url);
    return DPIgnoreAction;
}

static BOOL DPPeekLookAheadWanted(id page, NSURL *url) {
    NSEventModifierFlags mods = NSEvent.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask & ~NSEventModifierFlagCapsLock;
    return DPPeek.on && mods == NSEventModifierFlagShift && url && page && !DPPeekShows(page) && DPPeekCanOpen(page);
}

// Shift also types capitals, so wait for it to stand alone; the recheck covers Shift released with nothing to cancel it.
static void DPPeekLookAhead(void) {
    id page = DPPeekHoveredPage;
    NSURL *url = DPPeekHovered;
    NSUInteger turn = ++DPPeekLookAheadTurn;
    if (!DPPeekLookAheadWanted(page, url)) return DPPeekCool();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        if (turn == DPPeekLookAheadTurn && page == DPPeekHoveredPage && [url isEqual:DPPeekHovered] && DPPeekLookAheadWanted(page, url))
            DPPeekWarm(NSApp.keyWindow, page, url);
    });
}

static void DPWebContent_status(id self, SEL _cmd, id webContents, NSString *text) {
    DPCallOriginal(DPWebContent_status, self, webContents, text);
    DPPeekLink = text.length ? DPPeekLinkKey(text) : nil;
    DPPeekLinkPage = webContents;
    NSURL *url = text.length ? [NSURL URLWithString:text] : nil;
    if (!url && webContents != DPPeekHoveredPage) return;  // Other pages, the warm one included, clear their own.
    DPPeekHovered = DPPeekIsWeb(url) ? url : nil;
    DPPeekHoveredPage = webContents;
    DPPeekHoveredDelegate = self;
    DPPeekLookAhead();
}

void DPPeekOpenDragged(NSURL *url, NSPoint origin) {
    id page = DPPeekHoveredPage;
    if (DPPeekShows(page)) return DPPeekLoad(page, url);
    if (DPPeekCanOpen(page)) DPPeekOpen(NSApp.keyWindow, url, origin, DPPeekHoveredDelegate, page);
}

static void DPInstallPeek(void) {
    DPPeekInstallPages();
    DPPeekInstallZoom();
    DPPeekInstallCursor();
    DPOnLaunch(^{
        DPHook(DPDiaWebContent, @selector(webContents:didCreateNewWebContent:targetURL:disposition:), (IMP)DPWebContent_didCreate);
        DPHook(DPDiaWebContent, @selector(webContents:decidePolicyForNavigationAction:), (IMP)DPWebContent_decidePolicy);
        DPHook(DPDiaWebContent, @selector(webContents:didChangeStatusText:), (IMP)DPWebContent_status);
    });
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent *(NSEvent *event) {
        DPPeekPressed = DPPeekLink;
        DPPeekPressedPage = DPPeekLinkPage;
        DPPeekPressedAt = event.timestamp;
        return event;
    }];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged | NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (event.type == NSEventTypeKeyDown) DPPeekLookAheadTurn++;
        else DPPeekLookAhead();
        return event;
    }];
}

static NSString *DPVerifyPeek(DPPatch *patch) {
    Class delegate = objc_getClass(DPDiaWebContent);
    if (class_getMethodImplementation(delegate, @selector(webContents:decidePolicyForNavigationAction:)) != (IMP)DPWebContent_decidePolicy)
        return @"link clicks don't reach Peek";
    if (class_getMethodImplementation(delegate, @selector(webContents:didCreateNewWebContent:targetURL:disposition:)) != (IMP)DPWebContent_didCreate)
        return @"new windows don't reach Peek";
    return DPPeekZoomProblem();
}

DP_PATCH(DPPeek) {
    .key = @"peek",
    .order = 104,
    .title = @"Peek on Shift-Click",
    .detail = @"Shift-click a link to preview it in a card over the page, like Arc. Click outside, press Escape or ⌘W to close it, ⌘O to open it as a tab, or use the buttons beside it.",
    .symbol = @"eye.fill",
    .tint = @"systemMintColor",
    .section = @"Links",
    .classes = DPClasses(DPDiaBrowserContext, DPDiaWebContents, DPDiaWebContentsConfiguration, DPDiaContentPane),
    .install = DPInstallPeek,
    .verify = DPVerifyPeek,
    .rows = DPPeekSettingsRows,
    .hint = @"Tip: right after Dia starts, open or switch to any tab once to start Peek.",
};
