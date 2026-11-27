#import "SiteSearch.h"

// Dia also starts a site search when a shortcut is followed by Space, so "figma plugin" searches Figma instead of the web.
// Arc only used Tab, so while the patch is on Space is turned off in each profile the bar opens in. It's a saved Chromium
// setting, so the profiles it was turned off in are remembered and it's turned back on there once the patch is off, even
// in a profile first opened after that.

#define DPSpaceProfilesKey @"siteSearchSpaceOffIn"

static NSUserDefaults *DPSpaceDefaults(void) {
    static NSUserDefaults *defaults;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return defaults;
}

// A profile is told apart by its history database, the one path each has.
static NSString *DPProfileOf(id preferences) {
    NSURL *history = [preferences respondsToSelector:@selector(historyDatabaseFilePath)] ? [preferences valueForKey:@"historyDatabaseFilePath"] : nil;
    return [history isKindOfClass:NSURL.class] ? history.URLByDeletingLastPathComponent.path : nil;
}

static void DPSetSpace(id preferences, BOOL on) {
    NSString *profile = DPProfileOf(preferences);
    if (!profile || DPTesting || ![preferences respondsToSelector:@selector(setKeywordSearchSpaceTriggeringEnabled:)]) return;
    NSMutableArray *off = [[DPSpaceDefaults() stringArrayForKey:DPSpaceProfilesKey] ?: @[] mutableCopy];
    BOOL enabled = [[preferences valueForKey:@"keywordSearchSpaceTriggeringEnabled"] boolValue];
    if (!on && enabled) {  // Left alone where the user turned it off: it stays off once the patch is.
        [preferences setValue:@NO forKey:@"keywordSearchSpaceTriggeringEnabled"];
        if (![off containsObject:profile]) [off addObject:profile];
    } else if (on && [off containsObject:profile]) {
        [preferences setValue:@YES forKey:@"keywordSearchSpaceTriggeringEnabled"];
        [off removeObject:profile];
    } else return;
    [DPSpaceDefaults() setObject:off forKey:DPSpaceProfilesKey];
}

void DPTabOnly(NSWindow *window) {
    DPSetSpace(DPSitePreferences(window), !DPSiteSearch.on);
}

void DPApplySpace(void) {
    for (NSWindow *window in NSApp.windows) DPTabOnly(window);
}
