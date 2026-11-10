#import "Patches/Boosts/Boosts.h"

// Arc's own font rule, which leaves icon fonts alone.
static NSString *const DPNotIcons = @"*:not(i, .material-symbols-outlined, .material-icons)";

NSString *DPBoostStylesheet(NSDictionary *boost) {
    NSMutableString *css = [NSMutableString new];
    for (NSDictionary *zap in boost[@"zaps"])  // One rule each, so a bad selector only loses itself.
        [css appendFormat:@"%@ { display: none !important; }\n", zap[@"selector"]];
    if ([boost[@"font"] length]) [css appendFormat:@"%@ { font-family: \"%@\" !important; }\n", DPNotIcons, boost[@"font"]];
    [css appendString:boost[@"css"] ?: @""];
    return css;
}

// Effects match a host exactly, with no wildcards, so a boost for example.com also covers www.example.com, as in Arc.
NSArray<NSString *> *DPBoostHosts(NSString *domain) {
    return @[ domain, [@"www." stringByAppendingString:domain] ];
}

// A name to show until the page gives its own: the label before the public suffix, so en.wikipedia.org is Wikipedia.
// A short second-level label is taken for part of the suffix, as in bbc.co.uk.
NSString *DPBoostSiteName(NSString *domain) {
    NSArray<NSString *> *labels = [domain componentsSeparatedByString:@"."];
    if (labels.count < 2) return domain;
    NSString *name = labels[labels.count - 2];
    if (name.length <= 3 && labels.count > 2) name = labels[labels.count - 3];
    return [[name substringToIndex:1].uppercaseString stringByAppendingString:[name substringFromIndex:1]];
}

static NSString *const DPBoostFormat = @"diatweaks-boost";

static id DPOf(id value, Class cls) { return [value isKindOfClass:cls] ? value : nil; }

BOOL DPIsBoostDomain(NSString *domain) {
    static NSRegularExpression *host;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ host = [NSRegularExpression regularExpressionWithPattern:@"^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9-]{2,}$" options:0 error:nil]; });
    return domain.length && domain.length <= 253 && [host numberOfMatchesInString:domain options:0 range:NSMakeRange(0, domain.length)] == 1;
}

// A selector with a brace or a comment in it could end its rule and start another, so it's dropped.
static BOOL DPIsZapSelector(NSString *selector) {
    return selector.length && [selector rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"{}"]].location == NSNotFound
        && ![selector containsString:@"/*"];
}

// Only the fields a boost has, each of the type it should be. A file can come from anyone, and the picker's answer
// comes back through the page.
NSDictionary *DPCleanBoost(id raw) {
    NSDictionary *boost = DPOf(raw, NSDictionary.class);
    if (!boost) return nil;
    NSMutableArray *zaps = [NSMutableArray new];
    for (id zap in DPOf(boost[@"zaps"], NSArray.class)) {
        NSString *selector = DPOf(DPOf(zap, NSDictionary.class)[@"selector"], NSString.class);
        if (DPIsZapSelector(selector)) [zaps addObject:@{ @"selector" : selector, @"label" : DPOf(zap[@"label"], NSString.class) ?: selector }];
    }
    NSCharacterSet *breaksOut = [NSCharacterSet characterSetWithCharactersInString:@"\"\\{};<>\n"];  // The font sits inside a CSS string.
    NSString *font = [[DPOf(boost[@"font"], NSString.class) ?: @"" componentsSeparatedByCharactersInSet:breaksOut] componentsJoinedByString:@""];
    return @{
        @"enabled" : @([DPOf(boost[@"enabled"], NSNumber.class) ?: @YES boolValue]), @"zaps" : zaps, @"font" : font,
        @"css" : DPOf(boost[@"css"], NSString.class) ?: @"", @"js" : DPOf(boost[@"js"], NSString.class) ?: @"",
    };
}

NSData *DPBoostFileData(NSString *domain, NSDictionary *boost) {
    NSDictionary *file = @{ @"format" : DPBoostFormat, @"version" : @1, @"domain" : domain, @"boost" : DPCleanBoost(boost) ?: @{} };
    return [NSJSONSerialization dataWithJSONObject:file options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
}

NSDictionary *DPBoostFromFileData(NSData *data, NSString **domain, NSString **problem) {
    if (data.length > 1 << 20) return *problem = @"The file is too big to be a Boost.", nil;
    NSDictionary *file = DPOf(data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil, NSDictionary.class);
    if (![file[@"format"] isEqual:DPBoostFormat]) return *problem = @"This file isn’t a Boost.", nil;
    NSInteger version = [DPOf(file[@"version"], NSNumber.class) integerValue];
    if (version > 1) return *problem = @"This Boost comes from a newer DiaTweaks. Update DiaTweaks to import it.", nil;
    NSString *site = [DPOf(file[@"domain"], NSString.class) lowercaseString];
    NSDictionary *boost = DPCleanBoost(file[@"boost"]);
    if (version < 1 || !DPIsBoostDomain(site) || !boost) return *problem = @"This Boost file is damaged.", nil;
    *domain = site;
    return boost;
}
