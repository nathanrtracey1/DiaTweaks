#import "StdPatch/StdPatch.h"
#import "Providers.h"

NSData *DPChatAgentRequest(NSData *line, NSString *model);
NSArray<NSString *> *DPInstalledChatModels(void);
NSString *DPSelectedDiaChatModel(NSString *choice, NSArray<NSString *> *models, BOOL fallback);

extern DPPatch DPDiaChatModel, DPDiaChatModelFallback;
void DPInstallDiaModelOverview(void);
void DPRefreshDiaModelPicker(void);
NSString *DPVerifyDiaModelOverview(DPPatch *patch);

static NSString *const DPDefaultDiaModel = @"dia-default";

void DPApplyDiaChatModel(DPPatch *patch) {
    NSString *choice = patch->on ? DPChoice(patch) : nil;
    NSString *model = DPSelectedDiaChatModel(choice, DPInstalledChatModels(), DPDiaChatModelFallback.on);
    NSDictionary *provider = patch->on ? DPSelectedChatProvider() : nil;
    if (patch->on && !provider) provider = @{ @"api": @"dia", @"model": model ?: @"" };
    DPSetChatSafety(DPSelectedSafetyProvider());
    DPSetChatProvider(provider);
    DPSetChatModelErrorAction(patch->on && ![DPActiveChatChoice() isEqual:@"dia-default"]);
    DPRefreshChatGPTStatus();
    DPRefreshDiaModelPicker();
    [NSNotificationCenter.defaultCenter postNotificationName:DPPatchesDidChangeNotification object:nil];
}

static void DPInstallDiaChatModel(void) {
    DPInstallDiaModelOverview();
    DPInstallChatGPTPage();
    DPInstallChatModelErrors();
    [NSNotificationCenter.defaultCenter addObserverForName:@"DPSignOutChatAccount" object:nil queue:nil
        usingBlock:^(NSNotification *note) { DPCancelChatAccount(note.object); }];
    [NSNotificationCenter.defaultCenter addObserverForName:@"DPChatProvidersChanged" object:nil queue:NSOperationQueue.mainQueue
        usingBlock:^(NSNotification *note) { DPProviderChanged(); }];
    DPApplyDiaChatModel(&DPDiaChatModel);
    DPOnLaunch(^{
        [DPChatProviders ensureApple];
        DPApplyDiaChatModel(&DPDiaChatModel);
        if (!DPTesting) for (NSDictionary *account in DPChatProviders.accounts)
            [DPChatProviders refresh:account[@"id"] force:NO completion:^(NSString *error) {}];
    });
}

NSMenu *DPDiaChatModels(void) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Model"];
    [menu addItemWithTitle:@"Dia Default" action:nil keyEquivalent:@""].representedObject = DPDefaultDiaModel;
    NSArray *models = DPInstalledChatModels();
    for (NSString *model in models)
        [menu addItemWithTitle:model action:nil keyEquivalent:@""].representedObject = model;
    NSString *saved = DPChoice(&DPDiaChatModel);
    if (!DPDiaChatModelFallback.on && saved.length && ![saved hasPrefix:@"provider:"] && ![saved isEqual:DPDefaultDiaModel] && ![models containsObject:saved])
        [menu addItemWithTitle:saved action:nil keyEquivalent:@""].representedObject = saved;
    DPAppendProviderModels(menu, DPChatProviders.accounts);
    NSString *active = DPActiveChatChoice();
    if ([active hasPrefix:@"provider:"] && ![menu.itemArray filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSMenuItem *item, NSDictionary *bindings) {
        return [item.representedObject isEqual:active];
    }]].count) [menu addItemWithTitle:DPChatChoiceTitle(active) action:nil keyEquivalent:@""].representedObject = active;
    return menu;
}

DP_PATCH(DPDiaChatModel) {
    .key = @"diaChatModel",
    .order = 103,
    .title = @"Chat Model",
    .detail = @"Restart Dia if this tweak was off when Dia opened.",
    .hint = @"Model availability depends on your account.",
    .symbol = @"sparkles",
    .tint = @"systemPurpleColor",
    .section = @"AI",
    .classes = DPClasses(DPDiaCommandBarToolbar),
    .choice = @"diaChatModelChoice",
    .defaultChoice = @"dia-default",
    .choices = DPDiaChatModels,
    .rows = DPProviderRows,
    .install = DPInstallDiaChatModel,
    .apply = DPApplyDiaChatModel,
    .verify = DPVerifyDiaModelOverview,
};
