#import "StdPatch/StdPatch.h"

extern DPPatch DPSiteSearch;

// A site that can be searched from the command bar: `host` as typed ("amazon.com"), `name` as shown ("Amazon"), `url`
// with {searchTerms} where the query goes, and its brand `color`, nil if it's to come from its icon.
@interface DPSite : NSObject
@property(copy) NSString *host, *name, *url;
@property(strong) NSColor *color;
@end

DPSite *DPSiteFor(NSString *typed, NSWindow *window);  // nil if what was typed isn't a site to search.
NSURL *DPSiteSearchURL(DPSite *site, NSString *query);  // The site itself for an empty query.
DPSite *DPSiteOfField(NSTextView *text);  // The site chosen in the bar's field, nil if none.

NSImage *DPSiteIconFor(NSTextView *text, DPSite *site);
void DPShowChip(NSTextView *text, DPSite *site, NSImage *icon, NSColor *color);  // The site's icon and name in the field, or none for nil.
void DPShowSiteButton(NSTextView *text, DPSite *site, NSColor *color);  // Return's button goes to the site, or back to Dia's for nil.
void DPRefreshSiteButton(NSTextView *text);
NSImage *DPSiteIcon(DPSite *site);  // From Dia's own store of site icons, nil if it has none.
NSImage *DPLetterIcon(DPSite *site, NSColor *color);  // The site's first letter on its color.
NSColor *DPBrandColor(NSImage *icon);
NSColor *DPShade(NSColor *color, CGFloat hue, CGFloat brightness, CGFloat white);  // hue: a turn's fraction; white: how much to lighten.
void DPShowGlow(NSTextView *text, NSColor *color);  // The bar's edge in the site's color, or none for nil.
void DPRefreshGlow(NSTextView *text);  // Fitted to the bar again after it changes size.
void DPUpdateSuggestions(NSTextView *text);  // Hidden while a site is chosen.

void DPInstallSiteSuggestions(void);
void DPInstallSitePlaceholder(void);
void DPInstallSiteInline(void);
void DPInstallSiteChip(void);
void DPInstallSiteButton(void);
void DPGuardField(NSTextView *text, BOOL guard);  // Keeps Dia from completing words in the field.
NSString *DPTypedText(NSTextView *text);  // What was typed, without an address Dia filled in after it.

NSTextView *DPSearchingField(void);  // The field with a site chosen, if any.
void DPReturnWhenTyped(NSTextView *text, NSURL *url, int tries);  // Return, once Dia picks the address in the field.
CALayer *DPFlow(NSColor *color, CGFloat lineWidth, float opacity, BOOL pulses);  // Light flowing along an edge.
void DPBreathe(CALayer *layer);
