#import "SiteSearch.h"

#define DPDiaPlaceholderText "_TtC5ARCUI23TextViewWithPlaceholder"

// No placeholder while a site is chosen: the chip says where the words go, and Dia's "Search or enter address" or "Ask
// anything…" would say otherwise. Dia sets it from Swift, so it's changed where AppKit reads it to draw, as Turn Off AI
// changes it too.
static NSAttributedString *DPPlaceholder_get(NSTextView *self, SEL _cmd) {
    NSAttributedString *dia = DPCallOriginal(DPPlaceholder_get, self);
    DPSite *site = DPSiteSearch.on ? DPSiteOfField(self) : nil;
    return site ? [NSAttributedString new] : dia;
}

void DPInstallSitePlaceholder(void) {
    DPHook(DPDiaPlaceholderText, @selector(placeholderAttributedString), (IMP)DPPlaceholder_get);
}
