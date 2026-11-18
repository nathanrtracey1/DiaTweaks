#import "Patches/CommandBar/Tabs.h"

id DPScriptWindow(NSWindow *window) {
    for (id scripted in [(id)NSApp.delegate valueForKey:@"appleScriptWindows"])
        if ([[scripted valueForKey:@"windowId"] isEqual:window.identifier]) return scripted;
    return nil;
}

// Reading appleScriptWindows is the costly step, so look the window up once and pass it on.
id DPScriptTabIn(id scriptWindow, NSString *tabID) {
    for (id tab in [scriptWindow valueForKey:@"appleScriptTabs"])
        if ([[tab valueForKey:@"tabId"] isEqual:tabID]) return tab;
    return nil;
}

id DPScriptTab(NSWindow *window, NSString *tabID) { return DPScriptTabIn(DPScriptWindow(window), tabID); }

NSString *DPTabID(id tab) { return [tab valueForKey:@"tabId"]; }
NSString *DPActiveTabIDIn(id scriptWindow) { return DPTabID([scriptWindow valueForKey:@"activeTab"]); }
NSString *DPActiveTabID(NSWindow *window) { return DPActiveTabIDIn(DPScriptWindow(window)); }
void DPFocusTab(id tab) { [tab performSelector:@selector(focus:) withObject:nil]; }
static NSInteger DPOwnCloses;
static CFTimeInterval DPOwnClosesLapse;

void DPMarkOwnClose(void) {
    DPOwnCloses++;
    DPOwnClosesLapse = CACurrentMediaTime() + 1;
}

BOOL DPTakeOwnClose(void) {
    if (CACurrentMediaTime() > DPOwnClosesLapse) DPOwnCloses = 0;
    if (DPOwnCloses <= 0) return NO;
    DPOwnCloses--;
    return YES;
}

void DPCloseTab(id tab) {
    if (!tab) return;
    DPMarkOwnClose();
    [tab performSelector:@selector(close:) withObject:nil];
}
