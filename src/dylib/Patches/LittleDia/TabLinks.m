#import "LittleDia.h"
#import "Commands/GroupTabs/GroupTabs.h"
#import "Patches/Peek/Peek.h"

static NSString *const DPFromAllTabs = @"all", *const DPFromPinnedTabs = @"pinned";

static NSArray *DPList(id object, SEL sel) {
    NSArray *list = [object respondsToSelector:sel] ? DPMsg(object, sel) : nil;
    return [list isKindOfClass:NSArray.class] ? list : @[];
}

static NSURL *DPPageURL(id page) {
    id url = [page respondsToSelector:@selector(url)] ? DPMsg(page, @selector(url)) : nil;
    return [url isKindOfClass:NSURL.class] ? url : nil;
}

// A page can't be asked which tab it is in: scripting tab ids are UUIDs and a page's session id is a number. So it's the pinned icon
// showing its address, and only when no other tab shows it too.
static BOOL DPOnPinnedIcon(id page) {
    NSString *url = DPPageURL(page).absoluteString;
    BOOL pinnedHere = NO;
    for (id window in DPList(NSApp.delegate, @selector(appleScriptWindows)))
        for (id tab in DPList(window, @selector(appleScriptTabs))) {
            NSString *address = [tab respondsToSelector:@selector(URL)] ? DPText(DPMsg(tab, @selector(URL))) : nil;
            if (!url.length || ![address isEqual:url]) continue;
            if (![tab respondsToSelector:@selector(isPinned)] || !DPMsgBool(tab, @selector(isPinned))) return NO;
            pinnedHere = YES;
        }
    return pinnedHere;
}

// Scripting calls only the icons pinned; a pinned row says so in its menu.
static BOOL DPFromPinnedTab(id page) { return DPPeekInPinnedRow(NSApp.keyWindow, page) || DPOnPinnedIcon(page); }

static BOOL DPInLittleDia(id page) {
    for (NSWindow *window in NSApp.windows)
        if (DPIsLittleDiaWindow(window) && DPLittleDiaPage(window) == page) return YES;
    return NO;
}

static BOOL DPPlainClick(void) {
    NSEventModifierFlags held = NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagShift | NSEventModifierFlagControl;
    return !(NSEvent.modifierFlags & held);
}

// Little Dia opens through the front browser. That has to be the clicked page's own, and never a private one: a private window's link must not land in the normal profile.
static BOOL DPOpensInOwnProfile(id browser) {
    id context = [browser respondsToSelector:@selector(context)] ? DPMsg(browser, @selector(context)) : nil;
    id contextID = [context respondsToSelector:@selector(id)] ? DPMsg(context, @selector(id)) : nil;
    return browser && browser == DPCommandBrowser() && [contextID respondsToSelector:@selector(isIncognito)] && !DPMsgBool(contextID, @selector(isIncognito));
}

BOOL DPLittleDiaTakesTabLink(id page, NSURL *url, BOOL leavesPinned) {
    if (!DPLittleDia.on || !DPLittleDiaTabLinks.on || !DPPeekIsWeb(url) || !DPPlainClick() || !DPLittleDiaReady()) return NO;
    if (!page || DPInLittleDia(page) || DPPeekShows(page) || !DPPeekIsWeb(DPPageURL(page))) return NO;  // Not an extension's or Dia's own page.
    id browser = DPBrowserOfContents(page);  // The page's own: the key window can be another one.
    if (!DPOpensInOwnProfile(browser)) return NO;
    if (!leavesPinned && ![DPChoice(&DPLittleDiaTabLinks) isEqual:DPFromAllTabs] && !DPFromPinnedTab(page)) return NO;
    NSWindow *source = DPBrowserWindow(browser);  // Where the click was; noted now, as Little Dia becomes key next.
    dispatch_async(dispatch_get_main_queue(), ^{ DPOpenTabLinkInLittleDia(url, source); });  // Not from inside Chromium's callback.
    return YES;
}

static NSMenu *DPTabLinksChoices(void) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Open Links From"];
    [menu addItemWithTitle:@"Pinned Tabs" action:nil keyEquivalent:@""].representedObject = DPFromPinnedTabs;
    [menu addItemWithTitle:@"All Tabs" action:nil keyEquivalent:@""].representedObject = DPFromAllTabs;
    return menu;
}

// Peek owns the link hooks and asks Little Dia first, so check those are in place rather than adding a second hook.
static NSString *DPVerifyTabLinks(DPPatch *patch) {
    Class delegate = objc_getClass(DPDiaWebContent);
    SEL decide = @selector(webContents:decidePolicyForNavigationAction:);
    SEL created = @selector(webContents:didCreateNewWebContent:targetURL:disposition:);
    if (class_getMethodImplementation(delegate, decide) == DPDiaIMP(delegate, decide)) return @"link clicks don't reach Little Dia";
    if (class_getMethodImplementation(delegate, created) == DPDiaIMP(delegate, created)) return @"new tabs don't reach Little Dia";
    return nil;
}

DP_PATCH(DPLittleDiaTabLinks) {
    .key = @"littleDiaTabLinks",
    .order = 104,
    .title = @"Open Links from Tabs",
    .detail = @"Links that would open a new tab open in Little Dia over the page instead. "
              @"Choose pinned tabs only, including links that leave a pinned tab's site, or every tab. Clicks with Option, Command, Shift or Control held keep their usual meaning. Experimental.",
    .symbol = @"arrow.up.forward.app arrow.up.right.square",
    .tint = @"systemMintColor",
    .requires = @"littleDia",
    .choice = @"littleDiaTabLinksFrom",
    .defaultChoice = @"pinned",
    .choices = DPTabLinksChoices,
    .classes = DPClasses(DPDiaBrowserContext, DPDiaWebContents, DPDiaWebContentsConfiguration, DPDiaContentPane),
    .verify = DPVerifyTabLinks,
};
