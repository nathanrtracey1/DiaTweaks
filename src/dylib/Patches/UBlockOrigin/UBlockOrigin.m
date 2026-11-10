#import "StdPatch/StdPatch.h"
#import "Updates/Updates.h"
#import "Commands/GroupTabs/GroupTabs.h"
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>
#import <CommonCrypto/CommonDigest.h>
#import <objc/message.h>

extern DPPatch DPUBlockOrigin;

static NSString *DPExtensionFolder(void) {
    return DPAppSupport(@"DiaPatches/ublock-origin");
}

static BOOL gExtensionLoaded;

// Chromium computes an unpacked extension's ID from the SHA-256 of its folder path.
static NSString *DPExtensionID(NSString *folder) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    const char *path = folder.fileSystemRepresentation;
    if (!path) return @"";
    CC_SHA256(path, (CC_LONG)strlen(path), digest);
    NSMutableString *extId = [NSMutableString string];
    for (int i = 0; i < 16; i++) [extId appendFormat:@"%c%c", 'a' + (digest[i] >> 4), 'a' + (digest[i] & 15)];
    return extId;
}

static BOOL DPSetUpUBlockOrigin(void) {
    NSString *folder = DPExtensionFolder();
    NSString *manifest = [folder stringByAppendingPathComponent:@"manifest.json"];
    if ([NSFileManager.defaultManager fileExistsAtPath:manifest]) return YES;

    NSString *zip = [folder.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"uBlock0.chromium.zip"];

    unsigned long size = 0;
    uint8_t *bytes = getsectiondata(&_mh_dylib_header, "__TEXT", "__ubo_zip", &size);
    if (bytes && size > 0) {
        NSData *data = [NSData dataWithBytesNoCopy:bytes length:size freeWhenDone:NO];
        [NSFileManager.defaultManager createDirectoryAtPath:folder.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        [data writeToFile:zip atomically:YES];
    } else if (![NSFileManager.defaultManager fileExistsAtPath:zip]) {
        zip = [DPAppSupport(@"DiaPatches") stringByAppendingPathComponent:@"uBlock0.chromium.zip"];
    }

    if ([NSFileManager.defaultManager fileExistsAtPath:zip]) {
        [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        NSTask *task = [NSTask new];
        task.launchPath = @"/usr/bin/unzip";
        task.arguments = @[ @"-qo", zip, @"-d", folder.stringByDeletingLastPathComponent ];
        [task launch];
        [task waitUntilExit];
        NSString *unzipped = [folder.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"uBlock0.chromium"];
        if ([NSFileManager.defaultManager fileExistsAtPath:unzipped]) {
            [NSFileManager.defaultManager removeItemAtPath:folder error:nil];
            [NSFileManager.defaultManager moveItemAtPath:unzipped toPath:folder error:nil];
        }
        if (bytes && size > 0) {
            [NSFileManager.defaultManager removeItemAtPath:zip error:nil];
        }
    }
    return [NSFileManager.defaultManager fileExistsAtPath:[folder stringByAppendingPathComponent:@"manifest.json"]];
}

static NSString *DPUBlockOriginProblem(DPPatch *patch) {
    if (![NSFileManager.defaultManager fileExistsAtPath:[DPExtensionFolder() stringByAppendingPathComponent:@"manifest.json"]])
        return @"uBlock Origin extension files are missing.";
    return nil;
}

static void DPCheckUBlockOnInstance(id extensions, int retriesLeft) {
    if (!DPUBlockOrigin.on || !extensions) return;

    if (![extensions respondsToSelector:@selector(isExtensionSystemReady)]) return;
    BOOL ready = ((BOOL (*)(id, SEL))objc_msgSend)(extensions, @selector(isExtensionSystemReady));
    if (!ready) {
        if (retriesLeft > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                DPCheckUBlockOnInstance(extensions, retriesLeft - 1);
            });
        }
        return;
    }

    if (![extensions respondsToSelector:@selector(installedExtensions)]) return;
    NSArray *list = ((id (*)(id, SEL))objc_msgSend)(extensions, @selector(installedExtensions));
    if (![list isKindOfClass:NSArray.class]) return;

    NSString *folder = DPExtensionFolder();
    NSString *targetId = DPExtensionID(folder);
    BOOL found = NO;

    for (id info in list) {
        NSString *name = [info respondsToSelector:@selector(name)] ? [info valueForKey:@"name"] : @"";
        NSString *eid = [info respondsToSelector:@selector(id)] ? [info valueForKey:@"id"] : @"";
        BOOL enabled = [info respondsToSelector:@selector(enabled)] ? [[info valueForKey:@"enabled"] boolValue] : NO;
        if ([eid isEqualToString:targetId] || [name isEqualToString:@"uBlock Origin"]) {
            found = YES;
            if (!enabled && [extensions respondsToSelector:@selector(enableExtension:)]) {
                ((void (*)(id, SEL, id))objc_msgSend)(extensions, @selector(enableExtension:), eid);
            }
            break;
        }
    }

    if (!found && [extensions respondsToSelector:@selector(installExtensionFromUnpackedPath:completion:)]) {
        void (^block)(id, id) = ^(id res, id info) {
            if ([res isKindOfClass:NSString.class]) {
                if ([extensions respondsToSelector:@selector(enableExtension:)]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(extensions, @selector(enableExtension:), res);
                }
            } else if ([res respondsToSelector:@selector(id)]) {
                NSString *eid = [res valueForKey:@"id"];
                if ([extensions respondsToSelector:@selector(enableExtension:)]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(extensions, @selector(enableExtension:), eid);
                }
            }
        };
        ((void (*)(id, SEL, NSString *, id))objc_msgSend)(extensions, @selector(installExtensionFromUnpackedPath:completion:), folder, block);
    }
}

static id DPExtensions_init(id self, SEL _cmd, void *impl, id browserContext) {
    self = DPCallOriginal(DPExtensions_init, self, impl, browserContext);
    if (DPUBlockOrigin.on && self) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DPCheckUBlockOnInstance(self, 10);
        });
    }
    return self;
}

static void DPInstallUBlockOrigin(void) {
    if (!DPUBlockOrigin.on) return;
    if (!DPSetUpUBlockOrigin()) return;

    NSString *folder = DPExtensionFolder();
    NSString *extId = DPExtensionID(folder);

    // 1. Enable Manifest V2 availability in standard user defaults
    [NSUserDefaults.standardUserDefaults setInteger:2 forKey:@"ExtensionManifestV2Availability"];
    [NSUserDefaults.standardUserDefaults synchronize];

    // 2. Add extension to force-installed / settings policy so webRequestBlocking is permitted
    if (extId.length) {
        NSArray *forceList = @[ extId, @"cjpalhdlnbpafiamejdnhcphjbkeiagm" ];
        [NSUserDefaults.standardUserDefaults setObject:forceList forKey:@"ExtensionInstallForcelist"];
        [NSUserDefaults.standardUserDefaults synchronize];
    }

    // 3. Disable Chromium MV2 deprecation warning and disabled dialogs
    DPAddLaunchFlag(@"--disable-features=ExtensionManifestV2Disabled,ExtensionManifestV2DeprecationWarning");

    // 4. Hook ArcBrowserContextExtensions initialization to monitor & enable uBlock
    DPHook("ArcBrowserContextExtensions", @selector(initWithBrowserContextExtensions:forBrowserContext:), (IMP)DPExtensions_init);

    // 5. Load the unpacked extension
    DPLoadExtension(folder);
    gExtensionLoaded = YES;

    // 6. Also check via DPOnLaunch in case context was already created before hook
    DPOnLaunch(^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            id browser = DPCommandBrowser();
            id context = [browser respondsToSelector:@selector(context)] ? ((id (*)(id, SEL))objc_msgSend)(browser, @selector(context)) : nil;
            id extensions = [context respondsToSelector:@selector(extensions)] ? ((id (*)(id, SEL))objc_msgSend)(context, @selector(extensions)) : nil;
            if (extensions) {
                DPCheckUBlockOnInstance(extensions, 5);
            }
        });
    });
}

static void DPApplyUBlockOrigin(DPPatch *patch) {
    if (patch->on) DPSetUpUBlockOrigin();
    if (patch->on == gExtensionLoaded || patch->on != DPSavedOn(patch) || (patch->on && DPUBlockOriginProblem(patch))) return;
    NSAlert *alert = [NSAlert new];
    alert.messageText = patch->on ? @"Relaunch Dia to enable uBlock Origin" : @"Relaunch Dia to disable uBlock Origin";
    alert.informativeText = patch->on ? @"Dia will restart with uBlock Origin loaded with Manifest V2 and webRequestBlocking support."
                                      : @"Dia will restart without uBlock Origin.";
    [alert addButtonWithTitle:@"Relaunch"];
    [alert addButtonWithTitle:@"Later"];
    if ([alert runModal] == NSAlertFirstButtonReturn) DPHandOffAndQuit(@[ @"apply" ]);
}

DP_PATCH(DPUBlockOrigin) {
    .key = @"ublockOrigin",
    .order = 12,
    .defaultOn = YES,
    .title = @"uBlock Origin",
    .detail = @"Run the full uBlock Origin adblocker with Manifest V2 and webRequestBlocking.",
    .hint = @"Provides uBO's live logger, anti-adblock defusers, procedural cosmetic filters, and custom lists.",
    .symbol = @"shield.lefthalf.filled",
    .tint = @"systemBlueColor",
    .section = @"Page",
    .install = DPInstallUBlockOrigin,
    .apply = DPApplyUBlockOrigin,
    .ready = DPUBlockOriginProblem,
};
