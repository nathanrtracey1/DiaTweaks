#import "SiteSearch.h"
#import "Commands/GroupTabs/GroupTabs.h"

@implementation DPSite
@end

enum { DPNoColor = -1, DPMono = -2 };

// rgb: the site's brand color as 0xRRGGBB; DPMono for a black and white brand, which shows as the text color so it can
// be seen on a dark bar; DPNoColor to take it from the site's icon.
static DPSite *DPMakeSite(NSString *host, NSString *name, NSString *url, long rgb) {
    DPSite *site = [DPSite new];
    site.host = host;
    site.name = name;
    site.url = url;
    if (rgb == DPMono) site.color = NSColor.labelColor;
    else if (rgb >= 0) site.color = [NSColor colorWithSRGBRed:(rgb >> 16 & 0xFF) / 255.0 green:(rgb >> 8 & 0xFF) / 255.0 blue:(rgb & 0xFF) / 255.0 alpha:1];
    return site;
}

// Popular sites with clean search addresses, each in its brand color. Chromium's own list, learned from sites' search
// boxes, fills in the rest, with colors taken from their icons.
static NSArray<DPSite *> *DPBuiltInSites(void) {
    static NSArray *sites;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sites = @[
            DPMakeSite(@"amazon.com", @"Amazon", @"https://www.amazon.com/s?k={searchTerms}", 0xFF9900),
            DPMakeSite(@"youtube.com", @"YouTube", @"https://www.youtube.com/results?search_query={searchTerms}", 0xFF0000),
            DPMakeSite(@"google.com", @"Google", @"https://www.google.com/search?q={searchTerms}", 0x4285F4),
            DPMakeSite(@"wikipedia.org", @"Wikipedia", @"https://en.wikipedia.org/w/index.php?search={searchTerms}", DPMono),
            DPMakeSite(@"reddit.com", @"Reddit", @"https://www.reddit.com/search/?q={searchTerms}", 0xFF4500),
            DPMakeSite(@"github.com", @"GitHub", @"https://github.com/search?q={searchTerms}", DPMono),
            DPMakeSite(@"ebay.com", @"eBay", @"https://www.ebay.com/sch/i.html?_nkw={searchTerms}", 0xE53238),
            DPMakeSite(@"etsy.com", @"Etsy", @"https://www.etsy.com/search?q={searchTerms}", 0xF1641E),
            DPMakeSite(@"walmart.com", @"Walmart", @"https://www.walmart.com/search?q={searchTerms}", 0x0071DC),
            DPMakeSite(@"target.com", @"Target", @"https://www.target.com/s?searchTerm={searchTerms}", 0xCC0000),
            DPMakeSite(@"bestbuy.com", @"Best Buy", @"https://www.bestbuy.com/site/searchpage.jsp?st={searchTerms}", 0x0046BE),
            DPMakeSite(@"x.com", @"X", @"https://x.com/search?q={searchTerms}", DPMono),
            DPMakeSite(@"twitter.com", @"X", @"https://x.com/search?q={searchTerms}", DPMono),
            DPMakeSite(@"instagram.com", @"Instagram", @"https://www.instagram.com/explore/search/keyword/?q={searchTerms}", 0xE1306C),
            DPMakeSite(@"pinterest.com", @"Pinterest", @"https://www.pinterest.com/search/pins/?q={searchTerms}", 0xE60023),
            DPMakeSite(@"spotify.com", @"Spotify", @"https://open.spotify.com/search/{searchTerms}", 0x1DB954),
            DPMakeSite(@"maps.google.com", @"Google Maps", @"https://www.google.com/maps/search/{searchTerms}", 0x34A853),
            DPMakeSite(@"images.google.com", @"Google Images", @"https://www.google.com/search?tbm=isch&q={searchTerms}", 0x4285F4),
            DPMakeSite(@"duckduckgo.com", @"DuckDuckGo", @"https://duckduckgo.com/?q={searchTerms}", 0xDE5833),
            DPMakeSite(@"bing.com", @"Bing", @"https://www.bing.com/search?q={searchTerms}", 0x008373),
            DPMakeSite(@"perplexity.ai", @"Perplexity", @"https://www.perplexity.ai/search?q={searchTerms}", 0x20808D),
            DPMakeSite(@"chatgpt.com", @"ChatGPT", @"https://chatgpt.com/?q={searchTerms}", 0x10A37F),
            DPMakeSite(@"imdb.com", @"IMDb", @"https://www.imdb.com/find/?q={searchTerms}", 0xF5C518),
            DPMakeSite(@"netflix.com", @"Netflix", @"https://www.netflix.com/search?q={searchTerms}", 0xE50914),
            DPMakeSite(@"linkedin.com", @"LinkedIn", @"https://www.linkedin.com/search/results/all/?keywords={searchTerms}", 0x0A66C2),
            DPMakeSite(@"stackoverflow.com", @"Stack Overflow", @"https://stackoverflow.com/search?q={searchTerms}", 0xF48024),
            DPMakeSite(@"npmjs.com", @"npm", @"https://www.npmjs.com/search?q={searchTerms}", 0xCB3837),
            DPMakeSite(@"unsplash.com", @"Unsplash", @"https://unsplash.com/s/photos/{searchTerms}", DPMono),
            DPMakeSite(@"dribbble.com", @"Dribbble", @"https://dribbble.com/search/{searchTerms}", 0xEA4C89),
            DPMakeSite(@"behance.net", @"Behance", @"https://www.behance.net/search/projects?search={searchTerms}", 0x1769FF),
            DPMakeSite(@"fonts.google.com", @"Google Fonts", @"https://fonts.google.com/?query={searchTerms}", 0x4285F4),
            DPMakeSite(@"apple.com", @"Apple", @"https://www.apple.com/us/search/{searchTerms}", DPMono),
        ];
    });
    return sites;
}

// What was typed, as a bare host: no scheme, www., trailing slash or case.
static NSString *DPBareHost(NSString *typed) {
    NSString *text = [typed stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
    for (NSString *prefix in @[ @"https://", @"http://", @"www." ]) if ([text hasPrefix:prefix]) text = [text substringFromIndex:prefix.length];
    while ([text hasSuffix:@"/"]) text = [text substringToIndex:text.length - 1];
    return text;
}

static BOOL DPMatches(DPSite *site, NSString *bare) {
    if ([site.host isEqual:bare]) return YES;
    // "amazon" for amazon.com, but not "google" for maps.google.com.
    NSArray<NSString *> *labels = [site.host componentsSeparatedByString:@"."];
    return labels.count == 2 && [labels[0] isEqual:bare];
}

// The sites Chromium learned from search boxes, as Chrome's Tab to Search uses them; the search engines' own come too.
static NSArray<DPSite *> *DPChromiumSites(NSWindow *window) {
    id browser = DPBrowserOfWindow(window.parentWindow ?: window) ?: DPCommandBrowser();
    id context = [browser respondsToSelector:@selector(preferences)] ? browser : [browser respondsToSelector:@selector(context)] ? [(NSObject *)browser valueForKey:@"context"] : nil;
    id preferences = [context respondsToSelector:@selector(preferences)] ? [(NSObject *)context valueForKey:@"preferences"] : nil;
    NSArray *engines = [preferences respondsToSelector:@selector(getSearchEngines)] ? [preferences performSelector:@selector(getSearchEngines)] : nil;
    NSMutableArray *sites = [NSMutableArray new];
    for (NSObject *engine in [engines isKindOfClass:NSArray.class] ? engines : @[]) {
        NSString *keyword = [engine valueForKey:@"keyword"], *name = [engine valueForKey:@"name"], *url = [engine valueForKey:@"url"];
        if (![keyword isKindOfClass:NSString.class] || ![url isKindOfClass:NSString.class] || ![url containsString:@"{searchTerms}"]) continue;
        if ([keyword hasPrefix:@"@"] || ![url hasPrefix:@"http"]) continue;  // @bookmarks and @history open Chromium's own pages.
        NSString *host = DPBareHost(keyword);
        // An auto-added engine is named after its host; the part before the dot reads better.
        if (![name isKindOfClass:NSString.class] || !name.length || [DPBareHost(name) isEqual:host])
            name = [host componentsSeparatedByString:@"."].firstObject.capitalizedString;
        [sites addObject:DPMakeSite(host, name, url, DPNoColor)];
    }
    return sites;
}

DPSite *DPSiteFor(NSString *typed, NSWindow *window) {
    NSString *bare = DPBareHost(typed);
    if (!bare.length || [bare rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet].location != NSNotFound) return nil;
    for (DPSite *site in DPBuiltInSites()) if (DPMatches(site, bare)) return site;
    for (DPSite *site in DPChromiumSites(window)) if (DPMatches(site, bare)) return site;
    return nil;
}

NSURL *DPSiteSearchURL(DPSite *site, NSString *query) {
    if (!query.length) return [NSURL URLWithString:[@"https://" stringByAppendingString:site.host]];
    NSMutableCharacterSet *allowed = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
    [allowed removeCharactersInString:@"&+=#?/"];
    NSString *encoded = [query stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    NSString *url = [site.url stringByReplacingOccurrencesOfString:@"{searchTerms}" withString:encoded];
    // Chromium's other placeholders, such as {inputEncoding}, mean nothing outside its omnibox. Google's own drop out too.
    NSRegularExpression *rest = [NSRegularExpression regularExpressionWithPattern:@"\\{[^}]*\\}" options:0 error:nil];
    url = [rest stringByReplacingMatchesInString:url options:0 range:NSMakeRange(0, url.length) withTemplate:@""];
    return [NSURL URLWithString:url];
}
