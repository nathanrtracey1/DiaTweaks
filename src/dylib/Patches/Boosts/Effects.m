#import "Patches/Boosts/Boosts.h"
#import <objc/message.h>

// Browsers with a window. Their profile's context is a short-lived wrapper, so it's asked for each time; what's
// registered lives in the profile, so registering again under the same identifier just replaces it.
static NSHashTable *DPBrowsersWithWindows;

static id DPEffects(id browser) {
    id context = [browser respondsToSelector:@selector(context)] ? DPMsg(browser, @selector(context)) : nil;
    return [context respondsToSelector:@selector(effects)] ? DPMsg(context, @selector(effects)) : nil;
}

static NSString *DPSheetID(NSString *host) { return [@"diatweaks.boost.css." stringByAppendingString:host]; }

// What's on for `domain`, or nil.
static NSDictionary *DPActiveBoost(NSString *domain) {
    NSDictionary *boost = DPBoosts.on ? DPBoostFor(domain) : nil;
    return [boost[@"enabled"] boolValue] ? boost : nil;
}

// Effects match a host exactly and reach pages as they start loading.
static void DPRegister(id effects, NSString *host, NSDictionary *boost) {
    if (!effects) return;
    NSString *scriptID = [@"diatweaks.boost.js." stringByAppendingString:host], *tintID = [@"diatweaks.boost.tint." stringByAppendingString:host];
    void (*unregister)(id, SEL, NSString *) = (void *)objc_msgSend;
    unregister(effects, @selector(unregisterStylesheet:), DPSheetID(host));
    for (NSString *script in @[ scriptID, tintID ]) unregister(effects, @selector(unregisterScript:), script);
    if (!boost) return;
    void (*add)(id, SEL, NSString *, NSString *, NSString *) = (void *)objc_msgSend;
    NSString *sheet = DPBoostStylesheet(boost);
    if (sheet.length) add(effects, @selector(registerStylesheet:withIdentifier:forHostPattern:), sheet, DPSheetID(host), host);
    if (boost[@"color"]) add(effects, @selector(registerScript:withIdentifier:forHostPattern:), DPBoostTintScript(boost), tintID, host);  // Its own, so a mistake in the boost's script can't stop it.
    if ([boost[@"js"] length]) add(effects, @selector(registerScript:withIdentifier:forHostPattern:), boost[@"js"], scriptID, host);
}

// Pages already open keep the stylesheet Effects gave them as they loaded. A tab's own stylesheet under the same
// identifier replaces it at once, which is how the editor's changes show live, and the tint script paints the page
// again. The boost's own script waits for a reload.
static void DPRestyleOpenTabs(NSArray<NSString *> *hosts, NSDictionary *boost) {
    NSString *sheet = boost ? DPBoostStylesheet(boost) : @"";
    void (*remove)(id, SEL, NSString *) = (void *)objc_msgSend;
    void (*insert)(id, SEL, NSString *, NSString *) = (void *)objc_msgSend;
    for (id browser in DPBrowsersWithWindows.allObjects)
        for (id contents in DPTrackedContents(browser)) {
            NSString *host = [NSURL URLWithString:DPText(DPMsg(contents, @selector(url))) ?: @""].host;
            if (!host || ![hosts containsObject:host] || ![contents respondsToSelector:@selector(insertStylesheet:stylesheet:)]) continue;
            remove(contents, @selector(removeStylesheet:), DPSheetID(host));
            if (sheet.length) insert(contents, @selector(insertStylesheet:stylesheet:), DPSheetID(host), sheet);
            DPRunScript(contents, DPBoostTintScript(boost), ^(NSString *_) {});
        }
}

void DPApplyBoost(NSString *domain) {
    NSDictionary *boost = DPActiveBoost(domain);
    NSArray<NSString *> *hosts = DPBoostHosts(domain);
    for (id browser in DPBrowsersWithWindows.allObjects)
        for (NSString *host in hosts) DPRegister(DPEffects(browser), host, boost);
    DPRestyleOpenTabs(hosts, boost);
}

void DPApplyAllBoosts(void) {
    for (NSString *domain in DPBoostDomains()) DPApplyBoost(domain);
}

// From the profile's favicon store, so a site shows its icon without a tab open on it. ArcBrowserContext.h in ArcCore:
// -favicon:(NSURL *) iconTypes:(ArcFaviconType) sizeInPixels:(NSInteger) fallbackToHost:(BOOL) completion:^(NSImage *).
void DPLoadFavicon(NSString *domain, CGFloat points, void (^done)(NSImage *favicon)) {
    id browser = DPBrowsersWithWindows.anyObject;
    id context = [browser respondsToSelector:@selector(context)] ? DPMsg(browser, @selector(context)) : nil;
    SEL lookup = @selector(favicon:iconTypes:sizeInPixels:fallbackToHost:completion:);
    NSURL *page = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/", domain]];
    if (![context respondsToSelector:lookup] || !page) return done(nil);
    NSInteger plainFavicons = 1 << 0;  // ArcFaviconTypeFavicon
    ((void (*)(id, SEL, NSURL *, NSInteger, NSInteger, BOOL, void (^)(NSImage *)))objc_msgSend)(context, lookup, page, plainFavicons, points * 2, YES, ^(NSImage *favicon) {
        dispatch_async(dispatch_get_main_queue(), ^{ done([favicon isKindOfClass:NSImage.class] ? favicon : nil); });
    });
}

static void DPBrowser_setWindow(id self, SEL _cmd, NSWindow *window) {
    DPCallOriginal(DPBrowser_setWindow, self, window);
    if (!window || [DPBrowsersWithWindows containsObject:self]) return;
    [DPBrowsersWithWindows addObject:self];
    for (NSString *domain in DPBoostDomains())
        for (NSString *host in DPBoostHosts(domain)) DPRegister(DPEffects(self), host, DPActiveBoost(domain));
}

void DPInstallBoostEffects(void) {
    DPBrowsersWithWindows = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaBrowser, @selector(setWindow:), (IMP)DPBrowser_setWindow);
}
