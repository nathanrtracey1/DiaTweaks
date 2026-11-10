// What a boost turns into, without Dia:
// clang -fobjc-arc -Isrc/dylib -framework AppKit tests/boosts.m src/dylib/Patches/Boosts/Rules.m -o build/boosts && build/boosts
#import "Patches/Boosts/Boosts.h"
#import <assert.h>

DPPatch DPBoosts;  // Rules.m doesn't use it; Boosts.h declares it.

int main(void) {
    @autoreleasepool {
        NSArray *zaps = @[ @{ @"selector" : @".ad", @"label" : @"Ad" }, @{ @"selector" : @"", @"label" : @"empty" }, @{ @"selector" : @"#banner", @"label" : @"Banner" } ];
        NSDictionary *boost = DPCleanBoost(@{ @"zaps" : zaps, @"font" : @"Georgia", @"css" : @"p{}", @"js" : @"alert(1)" });
        NSString *css = DPBoostStylesheet(boost);
        assert([css containsString:@".ad { display: none !important; }\n"]);
        assert([css containsString:@"#banner { display: none !important; }\n"]);
        assert(![css containsString:@"\n { display"]);  // an empty selector adds no rule
        assert([css containsString:@"*:not(i, .material-symbols-outlined, .material-icons) { font-family: \"Georgia\" !important; }"]);
        assert([css hasSuffix:@"p{}"]);
        assert(DPBoostStylesheet(DPCleanBoost(@{})).length == 0);
        assert([DPCleanBoost(@{})[@"enabled"] boolValue] && !DPCleanBoost(@"not a boost"));

        assert([DPBoostHosts(@"example.com") isEqual:(@[ @"example.com", @"www.example.com" ])]);
        assert([DPBoostSiteName(@"en.wikipedia.org") isEqual:@"Wikipedia"] && [DPBoostSiteName(@"bbc.co.uk") isEqual:@"Bbc"]);
        assert([DPBoostSiteName(@"x.com") isEqual:@"X"] && [DPBoostSiteName(@"github.com") isEqual:@"Github"]);

        // A selector can't end its rule: the picker's answer comes back through the page.
        NSArray *sneaky = @[ @{ @"selector" : @"p } body { display: none" }, @{ @"selector" : @"a /* rest" }, @{ @"selector" : @"div.ok" } ];
        assert([DPCleanBoost(@{ @"zaps" : sneaky })[@"zaps"] isEqual:(@[ @{ @"selector" : @"div.ok", @"label" : @"div.ok" } ])]);

        // Files: what goes out comes back, and a file from anyone can't carry more than a boost.
        NSString *domain, *problem;
        assert([DPBoostFromFileData(DPBoostFileData(@"example.com", boost), &domain, &problem) isEqual:boost] && [domain isEqual:@"example.com"]);
        NSDictionary *hostile = @{ @"format" : @"diatweaks-boost", @"version" : @1, @"domain" : @"Example.COM",
                                   @"boost" : @{ @"font" : @"x\"; } body { display: none", @"zoom" : @50, @"extra" : @"dropped", @"zaps" : @[ @3, @{ @"selector" : @"p" } ] } };
        NSDictionary *clean = DPBoostFromFileData([NSJSONSerialization dataWithJSONObject:hostile options:0 error:nil], &domain, &problem);
        assert([domain isEqual:@"example.com"] && ![clean[@"font"] containsString:@"\""] && ![clean[@"font"] containsString:@"}"]);
        assert(!clean[@"zoom"] && !clean[@"extra"]);
        assert([clean[@"zaps"] isEqual:(@[ @{ @"selector" : @"p", @"label" : @"p" } ])]);
        for (NSString *bad in @[ @"", @"localhost", @"exa mple.com", @"../etc", @"a.b/c" ]) assert(!DPIsBoostDomain(bad));
        NSData *other = [NSJSONSerialization dataWithJSONObject:@{ @"format" : @"diatweaks-boost", @"version" : @2, @"domain" : @"a.com", @"boost" : @{} } options:0 error:nil];
        assert(!DPBoostFromFileData(other, &domain, &problem) && [problem containsString:@"newer"]);
        assert(!DPBoostFromFileData([@"not json" dataUsingEncoding:NSUTF8StringEncoding], &domain, &problem));
        puts("boosts: ok");
    }
    return 0;
}
