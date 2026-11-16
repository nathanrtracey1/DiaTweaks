#import "Providers.h"
#import "Settings/Settings.h"

static NSMenuItem *DPPreferencesItem(NSMenu *menu) {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.keyEquivalent isEqual:@","] && (item.keyEquivalentModifierMask & NSEventModifierFlagCommand)) return item;
        NSMenuItem *nested = item.submenu ? DPPreferencesItem(item.submenu) : nil;
        if (nested) return nested;
    }
    return nil;
}

static void DPOpenChatModelPage(NSUInteger retries) {
    for (NSTableView *table in DPFindViews("NSTableView")) {
        if (!DPIsKind(table.delegate, DPDiaSettingsSidebar) || table.numberOfRows < 3) continue;
        [table.window makeKeyAndOrderFront:nil];
        [table selectRowIndexes:[NSIndexSet indexSetWithIndex:table.numberOfRows - 1] byExtendingSelection:NO];
        [table.delegate tableViewSelectionDidChange:[NSNotification notificationWithName:NSTableViewSelectionDidChangeNotification object:table]];
        for (DPOverviewView *overview in DPFindViews("DPOverviewView")) {
            if (overview.window != table.window || overview.hiddenOrHasHiddenAncestor || !overview.open) continue;
            DPPatch *patch = DPPatchNamed(@"diaChatModel");
            overview.open(patch->title, [[DPPageView alloc] initWithPatch:patch]);
            return;
        }
    }
    if (retries) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ DPOpenChatModelPage(retries - 1); });
}

void DPOpenChatModelSettings(void) {
    NSMenuItem *item = DPPreferencesItem(NSApp.mainMenu);
    if (item.action) [NSApp sendAction:item.action to:item.target from:item];
    dispatch_async(dispatch_get_main_queue(), ^{ DPOpenChatModelPage(20); });
}
