// Boosts, like Arc's: per-site hidden elements, font, CSS and JavaScript. Dia ships the engine Arc's Boosts use
// (ArcBrowserContextEffects) but never calls it, so this registers each boost there. The editor is laid out like Arc's.
#import "StdPatch/StdPatch.h"
#import "Commands/GroupTabs/GroupTabs.h"

extern DPPatch DPBoosts;

// Rules.m: what a boost turns into. Foundation only, so tests/boosts.m builds it on its own. A boost is a dictionary:
// enabled, zaps (@[ @{ selector, label } ]), color (@{ hue, sat, light, dark }, only once one is picked), font, size (a
// percentage), case (a text-transform), css, js.
NSString *DPBoostStylesheet(NSDictionary *boost);
NSArray<NSString *> *DPBoostHosts(NSString *domain);
NSString *DPBoostSiteName(NSString *domain);
BOOL DPIsBoostDomain(NSString *domain);
NSArray<NSNumber *> *DPBoostSizes(void);
NSArray<NSString *> *DPBoostCases(void);
NSDictionary *DPCleanBoost(id raw);  // Known fields of the right types, with defaults; nil if it isn't a dictionary.
// A .diaboost file is JSON: { format: "diatweaks-boost", version: 1, domain, boost }.
NSData *DPBoostFileData(NSString *domain, NSDictionary *boost);
NSDictionary *DPBoostFromFileData(NSData *data, NSString **domain, NSString **problem);  // nil and a sentence in problem.

// Tint.m: a boost's color on a page. Foundation only too.
NSDictionary *DPBoostPalette(NSDictionary *color);  // What the stylesheet, the script and the editor's swatches agree on.
NSString *DPBoostTintRule(NSDictionary *color);     // "" without a color.
NSString *DPBoostTintScript(NSDictionary *boost);   // Recolors the page it runs on, or gives it its colors back without one.

// Boosts.m: saved in com.diapatches under "boostSites", keyed by domain.
NSDictionary *DPBoostFor(NSString *domain);
NSArray<NSString *> *DPBoostDomains(void);
void DPSaveBoost(NSString *domain, NSDictionary *boost);  // nil deletes it. Either way Dia applies it at once.
extern NSNotificationName const DPBoostsDidChangeNotification;

// Effects.m
void DPInstallBoostEffects(void);
void DPApplyBoost(NSString *domain);
void DPApplyAllBoosts(void);
void DPLoadFavicon(NSString *domain, CGFloat points, void (^done)(NSImage *favicon));  // nil if Dia has none for it.

// Page.m: the front tab.
id DPFrontContents(void);
NSString *DPFrontDomain(void);
void DPRunScript(id contents, NSString *script, void (^done)(NSString *result));  // On the main queue, nil if it can't run.
// Picker.m: each click on the page hands `picked` @{ selector, label }, as it came from the page, until Escape or DPStopPicking.
void DPPickElements(id contents, void (^picked)(NSDictionary *zap), void (^done)(void));
void DPStopPicking(id contents);
void DPPageSiteName(id contents, void (^done)(NSString *name));  // Only called if the page names itself.

// Button.m and Toolbar.m: the Boost button in each tab's address field.
@interface DPBoostButton : NSButton
- (void)sync;  // Pink while the front tab's site has a Boost on.
@end
void DPInstallBoostButton(void);
void DPSyncBoostButtons(void);
NSView *DPBoostButtonIn(NSWindow *window);  // The visible one, or nil.
NSString *DPVerifyBoostButtons(DPPatch *patch);

// Files.m: each runs on `window` as a sheet.
void DPExportBoost(NSString *domain, NSWindow *window);
void DPImportBoost(NSWindow *window);  // Opens the imported boost in the editor.

// Sites.m: the Options on Boosts' Settings page.
NSArray<NSView *> *DPBoostSettingsRows(void);

// Labels.m
NSImageView *DPBoostFavicon(NSString *domain, CGFloat points);  // A globe until the site's favicon loads.
NSTextField *DPBoostLabel(NSString *text);  // One line, cut short with an ellipsis rather than wrapped.
NSAttributedString *DPBoostTitle(NSString *name, NSString *domain, NSFontWeight weight);  // Wikipedia (en.wikipedia.org)

// Editor.m: a popover under the Boost button, else under the top of the front window.
void DPShowBoostEditor(NSString *domain);
void DPCloseBoostEditor(void);
