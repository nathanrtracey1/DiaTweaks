#import "SidebarAddress.h"

// The pane being typed in, or the first one: a split window has a toolbar for each page.
NSView *DPToolbarFor(NSWindow *window) {
    NSView *first = nil;
    NSResponder *responder = window.firstResponder;
    for (NSView *bar in DPFindViews(DPDiaToolbar)) {
        if (bar.window != window || bar.hiddenOrHasHiddenAncestor) continue;
        first = first ?: bar;
        if ([responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:bar.superview]) return bar;
    }
    return first;
}

NSString *DPToolbarAddress(NSView *toolbar) {
    NSView *field = DPFindView(toolbar, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaAddressField); });
    NSTextView *text = (NSTextView *)DPFindView(field, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextView.class]; });
    return text.string ?: @"";
}

NSView *DPToolbarControl(NSView *toolbar, NSString *label) {
    return DPFindView(toolbar, ^BOOL(NSView *view) { return DPHasLabel(view, label); });
}

BOOL DPToolbarControlEnabled(NSView *control) {
    return [control isKindOfClass:NSControl.class] ? ((NSControl *)control).enabled : control != nil;
}

void DPPressToolbarControl(NSView *control) {
    if (![control accessibilityPerformPress] && [control isKindOfClass:NSControl.class]) [(NSControl *)control performClick:nil];
}

static NSMenuItem *DPItemWithKey(NSMenu *menu, NSString *key) {
    for (NSMenuItem *item in menu.itemArray) {
        BOOL matches = [item.keyEquivalent isEqualToString:key] && item.keyEquivalentModifierMask == NSEventModifierFlagCommand;
        NSMenuItem *found = matches ? item : DPItemWithKey(item.submenu, key);
        if (found) return found;
    }
    return nil;
}

// ⌘L, which opens Dia's command bar with the page's address in it; DPInstallSidebarCommandBar moves it over the pill.
void DPEditAddress(NSWindow *window) {
    [window makeKeyAndOrderFront:nil];
    NSMenuItem *item = DPItemWithKey(NSApp.mainMenu, @"l");
    if (item) [item.menu performActionForItemAtIndex:[item.menu indexOfItem:item]];
    else NSBeep();
}
