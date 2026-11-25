#import "Patches/Boosts/Boosts.h"

static NSString *const DPBoostsKey = @"boostSites";  // "boosts" is the patch's switch.
NSNotificationName const DPBoostsDidChangeNotification = @"DPBoostsDidChange";
static NSArray<NSMenuItem *> *DPBoostItems;

static NSUserDefaults *DPBoostDefaults(void) {
    static NSUserDefaults *defaults;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return defaults;
}

static NSDictionary *DPAllBoosts(void) { return [DPBoostDefaults() dictionaryForKey:DPBoostsKey] ?: @{}; }

NSDictionary *DPBoostFor(NSString *domain) { return domain ? DPCleanBoost(DPAllBoosts()[domain]) : nil; }

NSArray<NSString *> *DPBoostDomains(void) { return [DPAllBoosts().allKeys sortedArrayUsingSelector:@selector(compare:)]; }

void DPSaveBoost(NSString *domain, NSDictionary *boost) {
    NSMutableDictionary *all = [DPAllBoosts() mutableCopy];
    all[domain] = boost;
    [DPBoostDefaults() setObject:all forKey:DPBoostsKey];
    DPApplyBoost(domain);
    [NSNotificationCenter.defaultCenter postNotificationName:DPBoostsDidChangeNotification object:domain];
}

static void DPOpenBoost(void) {
    NSString *domain = DPFrontDomain();
    if (!domain) return NSBeep();  // Not a web page.
    DPShowBoostEditor(domain);
}

static void DPAddBoostItems(void) {
    NSMenu *menu = nil;
    for (NSString *title in @[ @"Tab", @"Tabs", @"View" ]) menu = menu ?: [NSApp.mainMenu itemWithTitle:title].submenu;
    if (!menu) return (void)NSLog(@"DiaPatches: no menu for Boost This Site");
    NSMenuItem *boost = DPMenuItem(@"Boost This Site…", ^{ DPOpenBoost(); });
    boost.image = [NSImage imageWithSystemSymbolName:@"paintbrush.pointed" accessibilityDescription:nil];
    DPBoostItems = @[ NSMenuItem.separatorItem, boost ];
    for (NSMenuItem *item in DPBoostItems) {
        item.hidden = !DPBoosts.on;
        [menu addItem:item];
    }
}

static void DPInstallBoosts(void) {
    DPInstallBoostEffects();
    DPInstallBoostButton();
    DPOnLaunch(^{ DPAddBoostItems(); });
}

static void DPApplyBoosts(DPPatch *patch) {
    for (NSMenuItem *item in DPBoostItems) item.hidden = !patch->on;
    if (!patch->on) DPCloseBoostEditor();
    DPApplyAllBoosts();
    DPSyncBoostButtons();
}

static NSString *DPVerifyBoosts(DPPatch *patch) {
    if (!DPBoostItems) return @"no Boost This Site menu item";
    if (DPBoostItems[1].hidden == patch->on) return @"Boost This Site menu item doesn't match the switch";
    return DPVerifyBoostButtons(patch);
}

DP_PATCH(DPBoosts) {
    .key = @"boosts",
    .order = 11,
    .title = @"Boosts",
    .detail = @"Restyle any site like Arc’s Boosts: recolor it, change its font, text size and case, hide parts of it, or add your own CSS and JavaScript.",
    .hint = @"Tip: click the paintbrush in the address field to boost the site you’re on.",
    .symbol = @"paintbrush.pointed.fill paintbrush.fill",
    .tint = @"systemBlueColor",
    .section = @"Page",
    .classes = DPClasses(DPDiaBrowser, DPDiaBrowserDelegate, DPDiaBrowserContextEffects, DPDiaAddressField),
    .rows = DPBoostSettingsRows,
    .install = DPInstallBoosts,
    .apply = DPApplyBoosts,
    .verify = DPVerifyBoosts,
};
