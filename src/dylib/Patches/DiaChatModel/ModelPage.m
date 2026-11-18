#import "Providers.h"

extern DPPatch DPDiaChatModel, DPDiaChatModelFallback, DPDiaChatSafety;
NSArray<NSString *> *DPInstalledChatModels(void);
NSString *DPSelectedDiaChatModel(NSString *choice, NSArray<NSString *> *models, BOOL fallback);
NSMenu *DPDiaChatModels(void);
void DPGroupChatModelOptions(NSStackView *page, NSView *model, NSView *fallback, NSView *safety);

static BOOL DPIsModelPage(NSView *page) {
    return DPFindView(page, ^BOOL(NSView *view) {
        return [view isKindOfClass:NSTextField.class] && [((NSTextField *)view).stringValue isEqual:DPDiaChatModel.title];
    }) != nil;
}

static NSPopUpButton *DPModelPicker(NSView *page) {
    return (id)DPFindView(page, ^BOOL(NSView *view) {
        return [view isKindOfClass:NSPopUpButton.class] && [((NSPopUpButton *)view).menu.title isEqual:@"Model"];
    });
}

static NSView *DPModelOptionRow(NSView *page, NSString *title) {
    NSView *toggle = DPFindView(page, ^BOOL(NSView *view) {
        return [view isKindOfClass:NSSwitch.class] && DPHasLabel(view, title);
    });
    return toggle.superview.superview;
}

void DPOrderChatModelOptions(NSView *page) {
    if (!DPIsModelPage(page)) return;
    NSView *fallback = DPModelOptionRow(page, DPDiaChatModelFallback.title), *safety = DPModelOptionRow(page, DPDiaChatSafety.title);
    DPGroupChatModelOptions((id)page, DPModelPicker(page).superview, fallback, safety);
}

static NSString *DPModelPickerChoice(void) {
    return DPActiveChatChoice();
}

void DPRefreshDiaModelPicker(void) {
    for (NSView *page in DPFindViews("DPPageView")) {
        if (!DPIsModelPage(page)) continue;
        NSPopUpButton *picker = DPModelPicker(page);
        if (!picker) continue;
        picker.menu = DPDiaChatModels();
        for (NSMenuItem *item in picker.itemArray)
            if ([item.representedObject isEqual:DPModelPickerChoice()]) [picker selectItem:item];
    }
}

NSString *DPVerifyDiaModelPage(DPPatch *patch) {
    for (NSView *page in DPFindViews("DPPageView")) {
        if (page.hiddenOrHasHiddenAncestor || !DPIsModelPage(page)) continue;
        NSPopUpButton *picker = DPModelPicker(page);
        if (!picker) return @"the model picker is missing";
        if (![picker.selectedItem.representedObject isEqual:DPModelPickerChoice()]) return @"the model picker does not show the active choice";
        NSSwitch *fallback = (id)DPFindView(page, ^BOOL(NSView *view) {
            return [view isKindOfClass:NSSwitch.class] && DPHasLabel(view, DPDiaChatModelFallback.title);
        });
        if (!fallback || fallback.state != DPDiaChatModelFallback.on) return @"the fallback switch does not match its saved state";
        NSView *fallbackRow = DPModelOptionRow(page, DPDiaChatModelFallback.title), *safetyRow = DPModelOptionRow(page, DPDiaChatSafety.title);
        NSStackView *group = [fallbackRow.superview isKindOfClass:NSStackView.class] ? (id)fallbackRow.superview : nil;
        if (!group || safetyRow.superview != group ||
            [group.arrangedSubviews indexOfObject:fallbackRow] >= [group.arrangedSubviews indexOfObject:safetyRow])
            return @"the fallback option is not above Safety Check";
    }
    return nil;
}
