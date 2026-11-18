#import "StdPatch/StdPatch.h"

static NSMutableArray<NSString *> *DPExtensionFolders, *DPLaunchFlags, *DPDroppedFlags;

// Chromium keeps only the last of a flag, so a list flag given more than once becomes one listing every value.
static void DPMergeListFlag(NSMutableArray<NSString *> *args, NSString *flag) {
    NSMutableArray<NSString *> *values = [NSMutableArray array];
    NSUInteger first = NSNotFound;
    for (NSUInteger i = args.count; i-- > 0;)
        if ([args[i] hasPrefix:flag]) {
            [values insertObject:[args[i] substringFromIndex:flag.length] atIndex:0];
            [args removeObjectAtIndex:(first = i)];
        }
    if (values.count) [args insertObject:[flag stringByAppendingString:[values componentsJoinedByString:@","]] atIndex:first];
}

static NSMutableArray<NSString *> *DPListValues(NSString *list) {
    NSMutableArray<NSString *> *values = [NSMutableArray array];
    for (NSString *value in [list componentsSeparatedByString:@","])
        [values addObject:[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
    return values;
}

// A relaunch Dia starts itself repeats the flags it ran with, so a flag a tweak is off for has to come out again.
static void DPDropFlags(NSMutableArray<NSString *> *args) {
    for (NSString *dropped in DPDroppedFlags) {
        NSString *flag = [dropped substringToIndex:[dropped rangeOfString:@"="].location + 1];
        NSArray<NSString *> *values = DPListValues([dropped substringFromIndex:flag.length]);
        for (NSUInteger i = args.count; i-- > 0;) {
            if (![args[i] hasPrefix:flag]) continue;
            NSMutableArray<NSString *> *kept = DPListValues([args[i] substringFromIndex:flag.length]);
            [kept removeObjectsInArray:values];
            if (kept.count) args[i] = [flag stringByAppendingString:[kept componentsJoinedByString:@","]];
            else [args removeObjectAtIndex:i];
        }
    }
}

// Chromium keeps only the last --load-extension, so one flag lists every folder, Dia's own first.
// A relaunch repeats our folders, some renamed or removed since, so only the tweaks' current ones are kept.
static id DPConfiguration_init(id self, SEL _cmd, int argc, NSArray<NSString *> *argv, NSString *profilePath, NSUInteger applicationID,
                               BOOL isProduction, NSUInteger restorationPolicy, BOOL loadAllProfiles, BOOL quitRunLoop, NSString *suiteName) {
    static NSString *const flag = @"--load-extension=";
    NSString *ours = [DPAppSupport(@"DiaPatches") stringByAppendingString:@"/"];
    NSMutableArray<NSString *> *args = [argv mutableCopy], *folders = [NSMutableArray array];
    for (NSString *arg in argv)
        if ([arg hasPrefix:flag]) {
            for (NSString *folder in [[arg substringFromIndex:flag.length] componentsSeparatedByString:@","])
                if (![folder hasPrefix:ours]) [folders addObject:folder];
            [args removeObject:arg];
        }
    [folders addObjectsFromArray:DPExtensionFolders];
    if (folders.count) [args addObject:[flag stringByAppendingString:[folders componentsJoinedByString:@","]]];
    [args addObjectsFromArray:DPLaunchFlags];
    DPDropFlags(args);
    DPMergeListFlag(args, @"--enable-features=");
    DPMergeListFlag(args, @"--disable-features=");
    return DPCallOriginal(DPConfiguration_init, self, argc + ((int)args.count - (int)argv.count), args, profilePath, applicationID, isProduction,
                          restorationPolicy, loadAllProfiles, quitRunLoop, suiteName);
}

static void DPHookConfiguration(void) {
    if (DPExtensionFolders) return;
    DPExtensionFolders = [NSMutableArray array];
    DPLaunchFlags = [NSMutableArray array];
    DPDroppedFlags = [NSMutableArray array];
    DPHook("ArcBrowserApplicationConfiguration", @selector(init:argv:profilePath:applicationID:isProduction:sessionRestorationPolicy:shouldLoadAllProfilesAtStartup:quitRunLoopOnTermination:userDefaultsSuiteName:),
           (IMP)DPConfiguration_init);
}

void DPLoadExtension(NSString *folder) {
    DPHookConfiguration();
    if (![DPExtensionFolders containsObject:folder]) [DPExtensionFolders addObject:folder];
}

void DPAddLaunchFlag(NSString *flag) {
    DPHookConfiguration();
    [DPLaunchFlags addObject:flag];
}

void DPDropLaunchFlag(NSString *flag) {
    DPHookConfiguration();
    if (![DPDroppedFlags containsObject:flag]) [DPDroppedFlags addObject:flag];
}

void DPDropExtension(NSString *folder) {
    DPDropLaunchFlag([@"--load-extension=" stringByAppendingString:folder]);
}
