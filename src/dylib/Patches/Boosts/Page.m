#import "Patches/Boosts/Boosts.h"
#import <objc/message.h>

// The front window's focused tab, else its first visible one (2 is Chromium's Visibility::VISIBLE).
id DPFrontContents(void) {
    id visible = nil;
    for (id contents in DPTrackedContents(DPCommandBrowser())) {
        if ([contents respondsToSelector:@selector(hasFocus)] && DPMsgBool(contents, @selector(hasFocus))) return contents;
        if (!visible && [contents respondsToSelector:@selector(visibility)] && ((NSInteger (*)(id, SEL))objc_msgSend)(contents, @selector(visibility)) == 2) visible = contents;
    }
    return visible;
}

// The host as Chromium has it, so a Boost's host pattern matches it: DPDomainKey turns punycode into Unicode, which
// Effects never match. Without www., which DPBoostHosts adds back.
NSString *DPFrontDomain(void) {
    id contents = DPFrontContents();
    NSURL *url = [contents respondsToSelector:@selector(url)] ? [NSURL URLWithString:DPText(DPMsg(contents, @selector(url))) ?: @""] : nil;
    if (![@[ @"http", @"https" ] containsObject:url.scheme.lowercaseString]) return nil;
    NSString *host = url.host.lowercaseString;
    while ([host hasSuffix:@"."]) host = [host substringToIndex:host.length - 1];
    if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
    return host.length ? host : nil;
}

// Dia hands back the script's value as JSON: a string comes back quoted.
static NSString *DPDecoded(id result) {
    NSString *text = DPText(result);
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    id value = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil] : nil;
    return [value isKindOfClass:NSString.class] ? value : text;
}

void DPRunScript(id contents, NSString *script, void (^done)(NSString *result)) {
    if (![contents respondsToSelector:@selector(executeJavascript:completion:)]) return done(nil);
    ((void (*)(id, SEL, NSString *, void (^)(id)))objc_msgSend)(contents, @selector(executeJavascript:completion:), script, ^(id result) {
        NSString *text = DPDecoded(result);
        dispatch_async(dispatch_get_main_queue(), ^{ done(text); });
    });
}

// The page's own name for its site, such as GitHub where the domain only gives Github.
void DPPageSiteName(id contents, void (^done)(NSString *name)) {
    NSString *script = @"((document.querySelector('meta[property=\"og:site_name\"]') || document.querySelector('meta[name=\"application-name\"]')"
        "|| {}).content || '').trim()";
    DPRunScript(contents, script, ^(NSString *name) {
        if (name.length && name.length <= 60) done(name);
    });
}
