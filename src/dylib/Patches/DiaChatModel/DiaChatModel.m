#import "StdPatch/StdPatch.h"
#import "Updates/Updates.h"
#import "Patches/AgentTransport/AgentSocket.h"
#import "Providers.h"

NSData *DPChatAgentRequest(NSData *line, NSString *model);
NSArray<NSString *> *DPInstalledChatModels(void);
NSString *DPSelectedDiaChatModel(NSString *choice, NSArray<NSString *> *models, BOOL fallback);

extern DPPatch DPDiaChatModel, DPDiaChatModelFallback, DPTurnOffAI;
void DPInstallDiaModelOverview(void);
void DPRefreshDiaModelPicker(void);
NSString *DPVerifyDiaModelOverview(DPPatch *patch);

static NSString *const DPDefaultDiaModel = @"dia-default";

static BOOL gOfferedRelaunch, gAppliedTurnOffAI;

// Dia starts its chat agent once. One that started before this tweak was on can't be reached until Dia relaunches.
BOOL DPChatModelNeedsRelaunch(DPPatch *patch) {
    return patch->on && DPSavedOn(patch) && !DPTurnOffAI.on && DPAgentTransportInstalled() &&
        !DPAgentRelayRunning() && DPAgentServerRunning();
}

// Once per time the tweak is on, so changing the model while it waits doesn't ask again.
BOOL DPChatModelTakeRelaunchOffer(DPPatch *patch) {
    if (!patch->on) gOfferedRelaunch = NO;
    if (gOfferedRelaunch || !DPChatModelNeedsRelaunch(patch)) return NO;
    return gOfferedRelaunch = YES;
}

static void DPOfferChatModelRelaunch(DPPatch *patch) {
    if (DPTesting || !DPChatModelTakeRelaunchOffer(patch)) return;
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Relaunch Dia to choose a chat model";
    alert.informativeText = @"Dia's chat helper is already running without DiaTweaks.";
    [alert addButtonWithTitle:@"Relaunch"];
    [alert addButtonWithTitle:@"Later"];
    if ([alert runModal] == NSAlertFirstButtonReturn) DPHandOffAndQuit(@[ @"apply" ]);
}

// Off, paused and Turn Off AI all leave Dia's agent socket alone: no filter is registered, and one already running passes frames through.
void DPApplyDiaChatModel(DPPatch *patch) {
    gAppliedTurnOffAI = DPTurnOffAI.on;
    BOOL active = patch->on && !gAppliedTurnOffAI;
    NSString *model = active ? DPSelectedDiaChatModel(DPChoice(patch), DPInstalledChatModels(), DPDiaChatModelFallback.on) : nil;
    DPAgentFilter filter = nil;
    if (active) filter = ^NSData *(NSData *line, DPAgentReply reply) {
        return DPTurnOffAI.on ? line : DPChatAgentRequest(line, model);
    };
    DPSetChatProvider(active ? DPSelectedChatProvider() : nil, filter);
    DPRefreshDiaModelPicker();
    [NSNotificationCenter.defaultCenter postNotificationName:DPPatchesDidChangeNotification object:nil];
    DPOfferChatModelRelaunch(patch);
}

static void DPInstallDiaChatModel(void) {
    DPInstallDiaModelOverview();
    [NSNotificationCenter.defaultCenter addObserverForName:@"DPChatProvidersChanged" object:nil queue:NSOperationQueue.mainQueue
        usingBlock:^(NSNotification *note) { DPProviderChanged(); }];
    DPApplyDiaChatModel(&DPDiaChatModel);
    [NSNotificationCenter.defaultCenter addObserverForName:DPPatchesDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        if (DPDiaChatModel.on && DPTurnOffAI.on != gAppliedTurnOffAI) DPApplyDiaChatModel(&DPDiaChatModel);
    }];
    DPOnLaunch(^{
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
    for (NSDictionary *account in DPChatProviders.accounts) {
        [menu addItem:NSMenuItem.separatorItem];
        NSMenuItem *heading = [menu addItemWithTitle:account[@"name"] action:nil keyEquivalent:@""];
        heading.enabled = NO;
        for (NSDictionary *item in account[@"catalog"]) {
            if (![account[@"visibility"][item[@"id"]] boolValue]) continue;
            NSString *choice = [NSString stringWithFormat:@"provider:%@/%@", account[@"id"], item[@"id"]];
            [menu addItemWithTitle:item[@"name"] action:nil keyEquivalent:@""].representedObject = choice;
        }
    }
    NSString *active = DPActiveChatChoice();
    if ([active hasPrefix:@"provider:"] && ![menu.itemArray filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSMenuItem *item, NSDictionary *bindings) {
        return [item.representedObject isEqual:active];
    }]].count) [menu addItemWithTitle:DPChatChoiceTitle(active) action:nil keyEquivalent:@""].representedObject = active;
    return menu;
}

static NSString *DPVerifyDiaChatModel(DPPatch *patch) {
    BOOL active = patch->on && !DPTurnOffAI.on;
    if (active && !DPAgentTransportInstalled()) return @"Dia's agent launch doesn't reach the chat model filter";
    if (!active && DPAgentFiltersActive()) return @"a chat model filter is registered while the tweak is off";
    return DPVerifyDiaModelOverview(patch);
}

DP_PATCH(DPDiaChatModel) {
    .key = @"diaChatModel",
    .order = 260,
    .title = @"Chat Model",
    .detail = @"Choose a Dia model or add your own provider. If Dia’s chat helper was already running when you turn this on, DiaTweaks offers to relaunch Dia.",
    .hint = @"Model availability depends on your account. Dia’s own upgrade prompts still apply.",
    .symbol = @"sparkles",
    .tint = @"systemPurpleColor",
    .section = @"AI",
    .disabledBy = @"turnOffAI",
    .classes = DPClasses(DPDiaAssistantPanel),
    .choice = @"diaChatModelChoice",
    .defaultChoice = @"dia-default",
    .choices = DPDiaChatModels,
    .rows = DPProviderRows,
    .install = DPInstallDiaChatModel,
    .apply = DPApplyDiaChatModel,
    .verify = DPVerifyDiaChatModel,
};
