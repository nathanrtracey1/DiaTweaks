#import "Patches/ProfileEmoji/ProfileEmoji.h"

DPPatch DPProfileEmoji;  // Symbols.m needs no patch, but its header declares one.
static int failures;

static void expect(BOOL ok, NSString *what) {
    if (ok) return;
    failures++;
    printf("FAIL %s\n", what.UTF8String);
}

int main(void) {
    @autoreleasepool {
        NSArray<NSString *> *all = DPSymbolsMatching(@"");
        expect(all.count > 1000, [NSString stringWithFormat:@"only %lu symbols", all.count]);
        expect([all.firstObject isEqual:@"house.fill"], @"suggestions come first");
        expect([NSOrderedSet orderedSetWithArray:all].count == all.count, @"no symbol is listed twice");
        expect(![all containsObject:@"0.circle.ar"] && [all containsObject:@"0.circle"], @"a symbol drawn for another script is left out");
        for (NSString *name in all) expect(DPSymbolNamed(name) != nil, [NSString stringWithFormat:@"%@ doesn't load", name]);

        expect([DPSymbolsMatching(@"love") containsObject:@"heart.fill"], @"search finds Apple's keywords");
        expect([DPSymbolsMatching(@"HOUSE") containsObject:@"house.fill"], @"search ignores case");
        expect(DPSymbolsMatching(@"zzzz").count == 0, @"a symbol without keywords doesn't match everything");
        for (NSString *name in DPSymbolsMatching(@"heart fill"))
            expect([name containsString:@"fill"] || [name containsString:@"heart"], [NSString stringWithFormat:@"heart fill found %@", name]);
    }
    if (!failures) printf("all Profile Emoji symbol checks passed\n");
    return failures ? 1 : 0;
}
