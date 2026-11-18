#import "Providers.h"
#import "ChatErrorsScript.h"
#import <CommonCrypto/CommonDigest.h>
#import <objc/message.h>

static NSHashTable *DPChatModelPages;
static BOOL DPChatModelOverride, DPChatModelRestore;
static NSString *DPChatOrigin;
static char DPChatErrorPending;

static NSString *DPChatExtensionOrigin(void) {
    NSString *path = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"web-chat-resources/dist/manifest.json"];
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] ?: NSData.data options:0 error:nil];
    if (![manifest isKindOfClass:NSDictionary.class] || ![manifest[@"key"] isKindOfClass:NSString.class]) return nil;
    NSData *key = [[NSData alloc] initWithBase64EncodedString:manifest[@"key"] options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!key.length) return nil;
    unsigned char hash[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(key.bytes, (CC_LONG)key.length, hash);
    NSMutableString *identifier = [NSMutableString new];
    for (NSUInteger i = 0; i < 16; i++) [identifier appendFormat:@"%c%c", 'a' + (hash[i] >> 4), 'a' + (hash[i] & 15)];
    return identifier;
}

static void DPUpdateChatErrorPages(void) {
    if (!DPChatModelOverride && !DPChatModelRestore) return;
    BOOL pendingRestore = NO;
    NSString *script = [DPChatErrorsScript stringByReplacingOccurrencesOfString:@"__DIATWEAKS_MODEL_ENABLED__" withString:DPChatModelOverride ? @"true" : @"false"];
    for (id page in DPChatModelPages.allObjects) {
        if (DPGet(page, &DPChatErrorPending)) { pendingRestore = !DPChatModelOverride; continue; }
        if (![page respondsToSelector:@selector(executeJavascript:completion:)]) continue;
        if ([page respondsToSelector:@selector(visibility)] && !((NSInteger (*)(id, SEL))objc_msgSend)(page, @selector(visibility))) continue;
        NSURL *url = [page valueForKey:@"url"];
        if (![url isKindOfClass:NSURL.class] || ![url.scheme isEqual:@"chrome-extension"] || ![url.host isEqual:DPChatOrigin] ||
            ![@[@"/index.html", @"/chat.html"] containsObject:url.path]) continue;
        NSString *ticket = NSUUID.UUID.UUIDString;
        DPSet(page, &DPChatErrorPending, ticket);
        __weak id weakPage = page;
        void (^answer)(NSString *, BOOL) = ^(NSString *result, BOOL ok) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakPage && [DPGet(weakPage, &DPChatErrorPending) isEqual:ticket]) DPSet(weakPage, &DPChatErrorPending, nil);
                id decoded = result.length ? [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingFragmentsAllowed error:nil] : nil;
                NSString *action = [decoded isKindOfClass:NSString.class] ? decoded : result;
                if (DPChatModelOverride && [action isEqual:@"change-model"]) DPOpenChatModelSettings();
            });
        };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (weakPage && [DPGet(weakPage, &DPChatErrorPending) isEqual:ticket]) DPSet(weakPage, &DPChatErrorPending, nil);
        });
        ((void (*)(id, SEL, NSString *, id))objc_msgSend)(page, @selector(executeJavascript:completion:), script, answer);
    }
    DPChatModelRestore = pendingRestore;
}

static void DPModelPage_setVisibility(id self, SEL _cmd, NSInteger visibility) {
    [DPChatModelPages addObject:self];
    DPCallOriginal(DPModelPage_setVisibility, self, visibility);
    if (visibility) { DPChatModelRestore = YES; DPUpdateChatErrorPages(); }
}

void DPSetChatModelErrorAction(BOOL enabled) {
    DPChatModelRestore = DPChatModelOverride && !enabled;
    DPChatModelOverride = enabled;
    DPUpdateChatErrorPages();
}

void DPInstallChatModelErrors(void) {
    DPChatModelPages = [NSHashTable weakObjectsHashTable];
    DPChatOrigin = DPChatExtensionOrigin();
    if (!DPChatOrigin) return;
    DPHook(DPDiaWebContents, @selector(setVisibility:), (IMP)DPModelPage_setVisibility);
    [NSTimer scheduledTimerWithTimeInterval:0.35 repeats:YES block:^(NSTimer *timer) { DPUpdateChatErrorPages(); }];
}
