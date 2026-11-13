#import "SiteSearch.h"
#import <objc/message.h>

// With a site chosen the bar shows no suggestions, as Arc did: Dia's are pages and searches on the web at large, and
// Return already searches the site. The list is hidden and given no height, so the bar shrinks to the field.

static NSView *DPBarOf(NSView *view) {
    while (view && !DPIsKind(view, DPDiaCommandBar)) view = view.superview;
    return view;
}

static BOOL DPHidesSuggestions(NSView *suggestions) {
    if (!DPSiteSearch.on) return NO;
    NSTextView *text = (NSTextView *)DPFindView(DPBarOf(suggestions), ^BOOL(NSView *view) { return [view isKindOfClass:NSTextView.class]; });
    return DPSiteOfField(text) != nil;
}

static NSSize DPSuggestions_intrinsicContentSize(NSView *self, SEL _cmd) {
    NSSize size = DPCallOriginal(DPSuggestions_intrinsicContentSize, self);
    if (DPHidesSuggestions(self)) size.height = 0;
    return size;
}

static void DPSuggestions_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    DPCallOriginal(DPSuggestions_setHidden, self, hidden || DPHidesSuggestions(self));
}

// After a site is chosen or let go: the list hides or comes back, and the bar takes its new height.
void DPUpdateSuggestions(NSTextView *text) {
    NSView *bar = DPBarOf(text);
    NSView *suggestions = DPFindView(bar, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaCommandBarSuggestions); });
    if (!suggestions) return;
    suggestions.hidden = NO;  // The hook keeps it hidden while a site is chosen.
    [suggestions invalidateIntrinsicContentSize];
    bar.needsLayout = YES;
}

// With a site chosen there's nothing to suggest: Chromium isn't asked, and Dia gets an empty answer. With no suggestion
// it can't complete words into an address either, "g" into google.com.
static BOOL DPBrowser_autocomplete(id self, SEL _cmd, NSString *text, int cursor, BOOL prevent, BOOL fresh, id keyword, id *error, void (^completion)(id, BOOL)) {
    NSTextView *field = DPSearchingField();
    Class result = objc_getClass("ArcAutocompleteResult");
    if (!DPSiteSearch.on || !DPSiteOfField(field) || !completion || ![result instancesRespondToSelector:@selector(init:perProviderMatches:)])
        return DPCallOriginal(DPBrowser_autocomplete, self, text, cursor, prevent, fresh, keyword, error, completion);
    id empty = ((id (*)(id, SEL, id, id))objc_msgSend)([result alloc], @selector(init:perProviderMatches:), @[], @{});
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(empty, YES);
        DPRefreshSiteButton(field);  // Dia changes its Go button with each update.
    });
    return YES;
}

void DPInstallSiteSuggestions(void) {
    DPHook(DPDiaBrowser, @selector(autocomplete:cursorPosition:preventInlineAutocomplete:startFresh:keyword:error:completion:), (IMP)DPBrowser_autocomplete);
    DPHook(DPDiaCommandBarSuggestions, @selector(intrinsicContentSize), (IMP)DPSuggestions_intrinsicContentSize);
    DPHook(DPDiaCommandBarSuggestions, @selector(setHidden:), (IMP)DPSuggestions_setHidden);
}
