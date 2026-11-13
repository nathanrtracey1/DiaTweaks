#import "SiteSearch.h"

#define DPDiaSuggestionsView "_TtC15BoostCommandBar15SuggestionsView"

static NSTableView *DPSuggestionsOf(NSTextView *text) {
    return (NSTableView *)DPFindView(text.window.contentView, ^BOOL(NSView *view) {
        return [view isKindOfClass:NSTableView.class] && DPIsKind(((NSTableView *)view).delegate, DPDiaSuggestionsView);
    });
}

static NSString *DPRowText(NSTableView *table, NSInteger row) {
    if (row < 0 || row >= table.numberOfRows) return @"";
    NSMutableArray *parts = [NSMutableArray new];
    DPFindView([table rowViewAtRow:row makeIfNecessary:NO], ^BOOL(NSView *view) {
        if ([view isKindOfClass:NSTextField.class]) [parts addObject:((NSTextField *)view).stringValue];
        return NO;
    });
    return [parts componentsJoinedByString:@" | "];
}

// Return opens the suggestion Dia picked, which lags what's in the field. So it waits, up to `tries` times 20ms, until
// the pick is the address put there.
void DPReturnWhenTyped(NSTextView *text, NSURL *url, int tries) {
    NSTableView *table = DPSuggestionsOf(text);
    NSString *picked = DPRowText(table, table.selectedRow), *bare = [url.absoluteString substringFromIndex:@"https://".length];
    BOOL ready = [picked containsString:bare] || [picked containsString:[bare stringByRemovingPercentEncoding] ?: bare];
    if (!ready && tries > 0 && text.window)
        return (void)dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ DPReturnWhenTyped(text, url, tries - 1); });
    if (text.window) [text doCommandBySelector:@selector(insertNewline:)];
}
