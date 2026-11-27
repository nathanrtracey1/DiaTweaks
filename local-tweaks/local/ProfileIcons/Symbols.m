#import "ProfileEmoji.h"

static NSString *const DPGlyphs = @"/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources";
static NSString *const DPPrivateGlyphs = @"/System/Library/CoreServices/CoreGlyphsPrivate.bundle/Contents/Resources";
static NSArray<NSString *> *DPAllSymbols;
static NSDictionary<NSString *, NSArray<NSString *> *> *DPKeywords;

// Shown first, before the rest in Apple's order.
static NSArray<NSString *> *DPSuggestedSymbols(void) {
    return @[
        @"house.fill", @"briefcase.fill", @"graduationcap.fill", @"heart.fill", @"star.fill", @"bolt.fill", @"flame.fill", @"leaf.fill",
        @"moon.fill", @"sun.max.fill", @"cloud.fill", @"globe", @"gamecontroller.fill", @"music.note", @"book.fill", @"bookmark.fill",
        @"cart.fill", @"bag.fill", @"creditcard.fill", @"gift.fill", @"hammer.fill", @"paintbrush.fill", @"camera.fill", @"film.fill",
        @"airplane", @"car.fill", @"pawprint.fill", @"cup.and.saucer.fill", @"fork.knife", @"dumbbell.fill", @"person.fill", @"person.2.fill",
        @"building.2.fill", @"terminal.fill", @"chevron.left.forwardslash.chevron.right", @"flask.fill", @"lock.fill", @"shield.fill", @"sparkles",
    ];
}

NSImage *DPSymbolNamed(NSString *name) {
    SEL private = @selector(imageWithPrivateSystemSymbolName:accessibilityDescription:);
    NSImage *image = [NSImage respondsToSelector:private]
        ? ((NSImage * (*)(id, SEL, NSString *, NSString *))[NSImage methodForSelector:private])(NSImage.class, private, name, nil)
        : nil;
    return image ?: [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
}

// Every symbol this macOS has, public then private, read from the lists SF Symbols ships with it.
static void DPLoadSymbols(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Suffixes for the same symbol drawn for another script, such as 0.circle.ar.
        NSSet *scripts = [NSSet setWithArray:@[ @"ar", @"bn", @"el", @"gu", @"he", @"hi", @"ja", @"km", @"kn", @"ko", @"ml", @"mni", @"mr", @"my",
                                                @"or", @"pa", @"rtl", @"ru", @"sat", @"si", @"ta", @"te", @"th", @"zh" ]];
        NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];
        for (NSString *name in DPSuggestedSymbols()) if (DPSymbolNamed(name)) [names addObject:name];
        NSMutableDictionary *keywords = [NSMutableDictionary dictionary];
        for (NSString *folder in @[ DPGlyphs, DPPrivateGlyphs ]) {
            NSArray<NSString *> *order = [NSArray arrayWithContentsOfFile:[folder stringByAppendingPathComponent:@"symbol_order.plist"]];
            NSSet *all = [NSSet setWithArray:order ?: @[]];
            for (NSString *name in order) {
                if ([scripts containsObject:name.pathExtension] && [all containsObject:name.stringByDeletingPathExtension]) continue;
                if ([name rangeOfString:@"^[0-9A-F]{32}\\." options:NSRegularExpressionSearch].location != NSNotFound) continue;  // Apple's internal ones
                [names addObject:name];
            }
            [keywords addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:[folder stringByAppendingPathComponent:@"symbol_search.plist"]] ?: @{}];
        }
        DPAllSymbols = names.array;
        DPKeywords = keywords;
    });
}

// Each word has to be in the name or start one of the symbol's search keywords, so "heart" finds heart.fill and "love" does too.
NSArray<NSString *> *DPSymbolsMatching(NSString *query) {
    DPLoadSymbols();
    NSPredicate *notEmpty = [NSPredicate predicateWithFormat:@"length > 0"];
    NSArray<NSString *> *words = [[query.lowercaseString componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet] filteredArrayUsingPredicate:notEmpty];
    if (!words.count) return DPAllSymbols;
    return [DPAllSymbols filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *name, NSDictionary *_) {
        for (NSString *word in words) {
            BOOL found = [name containsString:word];
            for (NSString *key in DPKeywords[name]) found = found || [key hasPrefix:word];
            if (!found) return NO;
        }
        return YES;
    }]];
}
