#import "SiteSearch.h"

// The built-in sites are the US and English ones, amazon.com and en.wikipedia.org; with this off only the user's own site
// search works.
DP_PATCH(DPPopularSites) {
    .key = @"siteSearchPopularSites",
    .defaultOn = YES,
    .order = 94,
    .title = @"Include Popular Sites",
    .detail = @"Also search about 30 popular sites, such as amazon.com and youtube.com, without adding them to Dia's site search first. Your own site search shortcuts always come first.",
    .symbol = @"star.circle.fill star",
    .tint = @"systemOrangeColor",
    .requires = @"siteSearch",
};
