#import "SiteSearch.h"
#import <objc/message.h>

static char DPSiteKey;

static __weak NSTextView *DPSearching;  // The field with a site chosen, if any.

static DPSite *DPSiteOf(NSTextView *text) { return text ? DPGet(text, &DPSiteKey) : nil; }

DPSite *DPSiteOfField(NSTextView *text) { return DPSiteOf(text); }

NSTextView *DPSearchingField(void) { return DPSearching; }

// The site's brand color, else the strongest color in its icon. Layers take fixed colors, so a black and white brand's
// text color is settled for the bar's light or dark appearance now.
static NSColor *DPSiteColor(NSTextView *text, DPSite *site, NSImage *icon) {
    if (!site.color) return DPBrandColor(icon);
    __block NSColor *color = site.color;
    [text.effectiveAppearance performAsCurrentDrawingAppearance:^{ color = [NSColor colorWithCGColor:site.color.CGColor] ?: site.color; }];
    return color;
}

static void DPSetSite(NSTextView *text, DPSite *site) {
    DPSet(text, &DPSiteKey, site);
    DPGuardField(text, site != nil);
    NSImage *icon = site ? DPSiteIconFor(text, site) : nil;
    NSColor *color = site ? DPSiteColor(text, site, icon) : nil;
    if (site && !icon) icon = DPLetterIcon(site, color);
    DPShowChip(text, site, icon, color);
    DPShowGlow(text, color);
    DPShowSiteButton(text, site, color);
    DPUpdateSuggestions(text);
    if (site) DPSearching = text;
    else if (DPSearching == text) DPSearching = nil;
}

static void DPReplaceText(NSTextView *text, NSString *string) {
    [text setSelectedRange:NSMakeRange(0, text.string.length)];
    [text insertText:string replacementRange:NSMakeRange(0, text.string.length)];
}

#pragma mark Keys

static BOOL DPInput_command(NSView *self, SEL _cmd, NSTextView *text, SEL command) {
    if (!DPSiteSearch.on || text.hasMarkedText) return DPCallOriginal(DPInput_command, self, text, command);
    DPSite *site = DPSiteOf(text);
    if (!site) {
        if (command != @selector(insertTab:)) return DPCallOriginal(DPInput_command, self, text, command);
        site = DPSiteFor(text.string, text.window);
        if (!site) return DPCallOriginal(DPInput_command, self, text, command);
        DPSetSite(text, site);  // First, while the suggestions still show the site's icon.
        DPReplaceText(text, @"");
        return YES;
    }
    if (command == @selector(insertNewline:)) {
        NSString *query = [DPTypedText(text) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSURL *url = DPSiteSearchURL(site, query);
        DPSetSite(text, nil);
        DPReplaceText(text, url.absoluteString);
        DPReturnWhenTyped(text, url, 50);
        return YES;
    }
    if (command == @selector(deleteBackward:) && !text.string.length) {
        DPSetSite(text, nil);
        DPReplaceText(text, site.host);
        return YES;
    }
    if (command == @selector(insertTab:)) return YES;
    // Esc starts over: the site and the words go, and the bar stays open for a new search. Esc again closes it.
    if (command == @selector(cancelOperation:)) {
        DPSetSite(text, nil);
        DPReplaceText(text, @"");
        return YES;
    }
    return DPCallOriginal(DPInput_command, self, text, command);
}

// The bar's field is used again the next time it opens, so a site left from before goes when it closes.
static void DPText_viewDidMoveToWindow(NSTextView *self, SEL _cmd) {
    DPCallOriginal(DPText_viewDidMoveToWindow, self);
    if (DPSiteOf(self)) DPSetSite(self, nil);
}

static void DPInstallSiteSearch(void) {
    DPHook(DPDiaCommandBarText, @selector(textView:doCommandBySelector:), (IMP)DPInput_command);
    DPHookClass(NSTextView.class, @selector(viewDidMoveToWindow), (IMP)DPText_viewDidMoveToWindow);
    DPInstallSiteSuggestions();
    DPInstallSitePlaceholder();
    DPInstallSiteInline();
    DPInstallSiteChip();
    DPInstallSiteButton();
}

static void DPApplySiteSearch(DPPatch *patch) {
    if (patch->on) return;
    for (NSView *view in DPFindViews("NSTextView"))
        if (DPSiteOf((NSTextView *)view)) DPSetSite((NSTextView *)view, nil);
}

// Nothing shows until Tab is pressed, so this checks what it relies on: the bar's field still hands its keys over.
static NSString *DPVerifySiteSearch(DPPatch *patch) {
    Class input = objc_getClass(DPDiaCommandBarText);
    return patch->on && ![input instancesRespondToSelector:@selector(textView:doCommandBySelector:)] ? @"the command bar's field doesn't take keys" : nil;
}

DP_PATCH(DPSiteSearch) {
    .key = @"siteSearch",
    .order = 93,
    .title = @"Search Sites with Tab",
    .detail = @"Type a site such as amazon.com in the command bar and press Tab to search it: type what to look for and press Return, or Esc to start over. Works with popular sites and any site whose search box you've used.",
    .symbol = @"magnifyingglass.circle.fill magnifyingglass",
    .tint = @"systemOrangeColor",
    .section = @"Command Bar",
    .classes = DPClasses(DPDiaCommandBarText, DPDiaBrowser),
    .install = DPInstallSiteSearch,
    .apply = DPApplySiteSearch,
    .verify = DPVerifySiteSearch,
};
