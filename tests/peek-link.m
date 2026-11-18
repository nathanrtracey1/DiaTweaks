#import "Patches/Peek/Peek.h"
#import <objc/runtime.h>

static int failures;

static void expect(BOOL ok, NSString *what) {
    if (ok) return;
    failures++;
    printf("FAIL %s\n", what.UTF8String);
}

// The URL Dia navigates to for a click, and the text Dia's status line shows for the same link.
static void same(NSString *clicked, NSString *shown) {
    expect([DPPeekLinkKey(clicked) isEqual:DPPeekLinkKey(shown)], [NSString stringWithFormat:@"%@ should match %@", clicked, shown]);
}

static void differ(NSString *one, NSString *other) {
    expect(![DPPeekLinkKey(one) isEqual:DPPeekLinkKey(other)], [NSString stringWithFormat:@"%@ should not match %@", one, other]);
}

// What the key is, byte for byte, so a macOS that escapes differently cannot hide behind two keys that happen to agree.
static void key(NSString *address, NSString *want) {
    NSString *got = DPPeekLinkKey(address);
    expect([got isEqual:want], [NSString stringWithFormat:@"key of %@ is %@, want %@", address, got, want]);
}

static NSMutableArray<NSString *> *parsed;
static BOOL parsingFails;

// The key may hand NSURL an international host and nothing else: record every string it is asked to parse.
static void watchNSURL(void) {
    parsed = [NSMutableArray new];
    Method method = class_getClassMethod(NSURL.class, @selector(URLWithString:));
    IMP original = method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^NSURL *(id self, NSString *string) {
        [parsed addObject:string];
        if (parsingFails) return nil;
        return ((NSURL * (*)(id, SEL, NSString *)) original)(self, @selector(URLWithString:), string);
    }));
}

int main(void) {
    @autoreleasepool {
        watchNSURL();
        same(@"http://127.0.0.1:8470/x.html?same-blank", @"127.0.0.1:8470/x.html?same-blank");
        same(@"https://example.com/a/b?c=d", @"https://example.com/a/b?c=d");
        same(@"https://example.com/", @"example.com");
        same(@"https://example.com/a/", @"example.com/a/");
        same(@"https://example.com/a%20b", @"example.com/a b");
        same(@"https://example.com/?q=a%20b", @"example.com/?q=a b");
        same(@"https://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC%E8%AA%9E", @"ja.wikipedia.org/wiki/日本語");
        same(@"https://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC%E8%AA%9E", @"https://ja.wikipedia.org/wiki/日本語");
        same(@"https://example.com/s?q=caf%C3%A9&n=1%2B1", @"example.com/s?q=café&n=1%2B1");
        same(@"https://example.com/a%25b", @"example.com/a%25b");
        same(@"https://example.com/p#a%20b", @"example.com/p#a b");
        same(@"https://xn--mnchen-3ya.de/%C3%BC", @"münchen.de/ü");
        same(@"https://xn--wgv71a119e.jp/", @"日本語.jp");
        same(@"https://example.com/caf%C3%A9/a%20b/100%25/%E6%97%A5", @"example.com/café/a b/100%25/日");
        same(@"https://example.com/s?q=caf%C3%A9%20x&n=1%2B1&r=100%25", @"example.com/s?q=café x&n=1%2B1&r=100%");
        same(@"https://example.com/p?x#caf%C3%A9%2B%20%25", @"example.com/p?x#café%2B %25");
        same(@"https://example.com/a%7Cb%5Ec%22d", @"example.com/a|b^c\"d");
        same(@"https://example.com/a%5Bb%5D?x%5B%5D=caf%C3%A9#f%23g", @"example.com/a[b]?x[]=café#f#g");

        [parsed removeAllObjects];
        key(@"example.com/café b/日%25本", @"example.com/caf%C3%A9%20b/%E6%97%A5%25%E6%9C%AC");
        key(@"example.com/s?q=é%20x&n=1%2B1&r=100%", @"example.com/s?q=%C3%A9%20x&n=1%2B1&r=100%25");
        key(@"example.com/p#ü%2B x%25 %", @"example.com/p#%C3%BC%2B%20x%25%20%25");
        key(@"example.com/a%zz%4/%%41", @"example.com/a%25zz%254/%25%41");
        key(@"example.com/a%e6%97%A5", @"example.com/a%e6%97%A5");
        key(@"example.com/a|b^c\"d<e>f`g{h}i\\j", @"example.com/a%7Cb%5Ec%22d%3Ce%3Ef%60g%7Bh%7Di%5Cj");
        key(@"example.com/a[b]?x[]=é#f#g[", @"example.com/a%5Bb%5D?x%5B%5D=%C3%A9#f%23g%5B");
        key(@"http://127.0.0.1:8470/x.html?a=b&c=d;e#f", @"127.0.0.1:8470/x.html?a=b&c=d;e#f");
        key(@"https://user@example.com:8080/a/", @"user@example.com:8080/a");
        key(@"https://example.com", @"example.com");
        expect(!parsed.count, @"an address with an ASCII host never reaches NSURL");
        key(@"münchen.localhost:8470/ü?q=é%20#%C3%BC", @"xn--mnchen-3ya.localhost:8470/%C3%BC?q=%C3%A9%20#%C3%BC");
        expect([parsed isEqualToArray:@[ @"http://münchen.localhost:8470" ]], [NSString stringWithFormat:@"only the host is handed to NSURL, got %@", parsed]);
        parsingFails = YES;  // A macOS whose NSURL does not take an international host: the key keeps it, so the link is missed, never mistaken for another.
        key(@"münchen.de/ü?q=é", @"münchen.de/%C3%BC?q=%C3%A9");
        differ(@"https://xn--mnchen-3ya.de/%C3%BC", @"münchen.de/ü");
        parsingFails = NO;

        differ(@"https://example.com/a", @"example.com/b");
        differ(@"https://example.com/a%20b", @"example.com/a_b");
        differ(@"https://example.com/a%2Fb", @"example.com/a/b");
        differ(@"https://example.com/a/b", @"example.com/a");
        differ(@"https://example.com/a?b", @"example.com/a");
        differ(@"https://example.com/a#b", @"example.com/a");
        differ(@"https://ja.wikipedia.org/wiki/%E6%97%A5", @"ja.wikipedia.org/wiki/%E6%9C%AC");
        differ(@"https://example.com/s?q=caf%C3%A9", @"example.com/s?q=cafe");
        differ(@"https://xn--mnchen-3ya.de/", @"munchen.de");
        differ(@"https://example.com/a%25b", @"example.com/a%2Fb");
        differ(@"https://example.com/caf%C3%A9/x", @"example.com/cafe/x");
        differ(@"https://example.com/p#caf%C3%A9%20", @"example.com/p#cafe%20");
        differ(@"https://example.com/s?q=caf%C3%A9%2B1", @"example.com/s?q=café+1");
    }
    if (failures) printf("%d failures\n", failures);
    else printf("peek links ok\n");
    return failures ? 1 : 0;
}
