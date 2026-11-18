#import "StdPatch/StdPatch.h"

// Stand-in for Dia's configuration: it records the argv the hook hands on.
static NSArray<NSString *> *seen;
static int seenCount;

@interface ArcBrowserApplicationConfiguration : NSObject
- (id)init:(int)argc argv:(NSArray<NSString *> *)argv profilePath:(NSString *)profilePath applicationID:(NSUInteger)applicationID
         isProduction:(BOOL)isProduction sessionRestorationPolicy:(NSUInteger)restorationPolicy shouldLoadAllProfilesAtStartup:(BOOL)loadAllProfiles
         quitRunLoopOnTermination:(BOOL)quitRunLoop userDefaultsSuiteName:(NSString *)suiteName;
@end
@implementation ArcBrowserApplicationConfiguration
- (id)init:(int)argc argv:(NSArray<NSString *> *)argv profilePath:(NSString *)profilePath applicationID:(NSUInteger)applicationID
         isProduction:(BOOL)isProduction sessionRestorationPolicy:(NSUInteger)restorationPolicy shouldLoadAllProfilesAtStartup:(BOOL)loadAllProfiles
         quitRunLoopOnTermination:(BOOL)quitRunLoop userDefaultsSuiteName:(NSString *)suiteName {
    seen = argv;
    seenCount = argc;
    return [super init];
}
@end

NSString *DPAppSupport(NSString *path) { return [@"/Users/test/Library/Application Support" stringByAppendingPathComponent:path]; }

#import "StdPatch/Extensions.m"

static NSString *const kDia = @"/Applications/Dia.app/Contents/MacOS/Dia";

// What Dia is handed once these folders are wanted, as a fresh launch of a Dia that started with `argv`.
static NSArray<NSString *> *DPLaunch(NSArray<NSString *> *wanted, NSArray<NSString *> *argv) {
    DPHookConfiguration();
    [DPExtensionFolders removeAllObjects];
    [DPLaunchFlags removeAllObjects];
    [DPDroppedFlags removeAllObjects];
    for (NSString *folder in wanted) DPLoadExtension(folder);
    (void)[[ArcBrowserApplicationConfiguration alloc] init:(int)argv.count argv:argv profilePath:@"" applicationID:1 isProduction:YES
                                  sessionRestorationPolicy:0 shouldLoadAllProfilesAtStartup:NO quitRunLoopOnTermination:NO userDefaultsSuiteName:nil];
    NSCAssert(seenCount == (int)seen.count, @"argc follows the argv it was given");
    return seen;
}

int main(void) {
    @autoreleasepool {
        NSString *little = DPAppSupport(@"DiaPatches/little-dia-2ee7906f"), *older = DPAppSupport(@"DiaPatches/little-dia-48da710a");
        NSString *passkeys = DPAppSupport(@"DiaPatches/passkeys-extension"), *mine = @"/Users/test/Developer/my-extension";
        NSString *other = @"/Users/test/Developer/another-extension";
        NSString *sibling = DPAppSupport(@"DiaPatches-old/extension"), *prefixed = DPAppSupport(@"DiaPatchesExtra/extension");
        NSString *(^load)(NSString *) = ^(NSString *list) { return [@"--load-extension=" stringByAppendingString:list]; };
        NSString *(^pair)(NSString *, NSString *) = ^(NSString *a, NSString *b) { return [NSString stringWithFormat:@"%@,%@", a, b]; };

        NSCAssert([DPLaunch(@[], @[ kDia ]) isEqual:@[ kDia ]], @"nothing wanted, nothing added");
        NSCAssert([DPLaunch(@[ little ], @[ kDia ]) isEqual:(@[ kDia, load(little) ])], @"a wanted folder is loaded");
        NSCAssert([DPLaunch(@[ little, passkeys ], @[ kDia ]) isEqual:(@[ kDia, load(pair(little, passkeys)) ])], @"every wanted folder shares one flag");

        NSArray<NSString *> *got = DPLaunch(@[ little ], @[ kDia, load(little), @"--restart" ]);
        NSCAssert([got isEqual:(@[ kDia, @"--restart", load(little) ])], @"a relaunch lists its folder once, got %@", got);
        got = DPLaunch(@[ little ], @[ kDia, load(@"/a"), @"--restart", @"--restart" ]);
        NSCAssert([got isEqual:(@[ kDia, @"--restart", @"--restart", load(pair(@"/a", little)) ])], @"other flags keep their order, got %@", got);

        got = DPLaunch(@[ little ], @[ kDia, load(pair(little, little)) ]);
        NSCAssert([got isEqual:(@[ kDia, load(little) ])], @"a folder carried twice comes back once, got %@", got);
        got = DPLaunch(@[ little ], @[ kDia, load(pair(pair(little, little), little)) ]);
        NSCAssert([got isEqual:(@[ kDia, load(little) ])], @"later relaunches don't add another copy, got %@", got);

        got = DPLaunch(@[ little ], @[ kDia, load(older) ]);
        NSCAssert([got isEqual:(@[ kDia, load(little) ])], @"a folder an update replaced is dropped, got %@", got);
        got = DPLaunch(@[ little ], @[ kDia, load(pair(older, little)), @"--restart" ]);
        NSCAssert([got isEqual:(@[ kDia, @"--restart", load(little) ])], @"the old folder goes, the current one stays, got %@", got);
        got = DPLaunch(@[], @[ kDia, load(older), @"--restart" ]);
        NSCAssert([got isEqual:(@[ kDia, @"--restart" ])], @"with the tweak off no folder is carried, got %@", got);
        got = DPLaunch(@[ passkeys ], @[ kDia, load(pair(pair(passkeys, older), little)) ]);
        NSCAssert([got isEqual:(@[ kDia, load(passkeys) ])], @"only the tweaks that are on keep a folder, got %@", got);
        got = DPLaunch(@[ little, passkeys ], @[ kDia, load(pair(pair(passkeys, older), little)) ]);
        NSCAssert([got isEqual:(@[ kDia, load(pair(little, passkeys)) ])], @"each wanted folder once, in the order it was added, got %@", got);

        got = DPLaunch(@[ little ], @[ kDia, load(pair(mine, older)) ]);
        NSCAssert([got isEqual:(@[ kDia, load(pair(mine, little)) ])], @"the user's own folder survives and stays first, got %@", got);
        got = DPLaunch(@[ little ], @[ kDia, load(mine), load(other), load(older) ]);
        NSCAssert([got isEqual:(@[ kDia, load(pair(pair(mine, other), little)) ])], @"several flags of the user's still merge, got %@", got);
        got = DPLaunch(@[], @[ kDia, load(pair(pair(sibling, older), prefixed)) ]);
        NSCAssert([got isEqual:(@[ kDia, load(pair(sibling, prefixed)) ])], @"folders beside DiaPatches aren't ours, got %@", got);
        got = DPLaunch(@[], @[ kDia, load(mine) ]);
        NSCAssert([got isEqual:(@[ kDia, load(mine) ])], @"a user's folder alone is untouched, got %@", got);
        got = DPLaunch(@[], @[ kDia, load(pair(mine, mine)) ]);
        NSCAssert([got isEqual:(@[ kDia, load(pair(mine, mine)) ])], @"the user's own repeats are theirs to keep, got %@", got);

        puts("all launch flag checks passed");
    }
}
