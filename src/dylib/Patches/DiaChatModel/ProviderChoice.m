#import "Providers.h"

extern DPPatch DPDiaChatModel, DPDiaChatModelFallback;
NSArray<NSString *> *DPInstalledChatModels(void);
NSString *DPSelectedDiaChatModel(NSString *, NSArray<NSString *> *, BOOL);
void DPRefreshDiaModelPicker(void);
void DPApplyDiaChatModel(DPPatch *);

static NSDictionary *DPSelectedProvider(BOOL credentials) {
    NSString *choice = DPChoice(&DPDiaChatModel);
    if (![choice hasPrefix:@"provider:"]) return nil;
    NSArray *parts = [[choice substringFromIndex:9] componentsSeparatedByString:@"/"];
    NSString *identifier = parts.firstObject;
    NSString *model = [choice substringFromIndex:MIN(choice.length, 10 + identifier.length)];
    NSMutableDictionary *provider = [(credentials ? [DPChatProviders snapshot:identifier] : [DPChatProviders account:identifier]) mutableCopy];
    if (!model.length) provider[@"error"] = @"This provider model is no longer configured.";
    provider[@"model"] = model;
    return provider;
}

NSDictionary *DPSelectedChatProvider(void) { return DPSelectedProvider(YES); }
NSDictionary *DPSelectedChatAccount(void) { return DPSelectedProvider(NO); }

NSString *DPActiveChatChoice(void) {
    NSString *choice = DPChoice(&DPDiaChatModel);
    if ([choice hasPrefix:@"provider:"]) return choice;
    return DPSelectedDiaChatModel(choice, DPInstalledChatModels(), DPDiaChatModelFallback.on) ?: @"dia-default";
}

NSString *DPChatChoiceTitle(NSString *choice) {
    if ([choice isEqual:@"dia-default"]) return @"Dia Default";
    if (![choice hasPrefix:@"provider:"]) return choice;
    for (NSDictionary *provider in DPChatProviders.accounts) {
        NSString *prefix = [NSString stringWithFormat:@"provider:%@/", provider[@"id"]];
        if (![choice hasPrefix:prefix]) continue;
        NSString *model = [choice substringFromIndex:prefix.length];
        for (NSDictionary *item in provider[@"catalog"])
            if ([item[@"id"] isEqual:model]) return [NSString stringWithFormat:@"%@ · %@", provider[@"name"], item[@"name"]];
        return [NSString stringWithFormat:@"%@ · %@", provider[@"name"], model];
    }
    return @"Unavailable provider model";
}

void DPProviderChanged(void) {
    DPApplyDiaChatModel(&DPDiaChatModel);
}

NSArray<NSView *> *DPProviderRows(void) {
    return [@[DPInlineProviderList()] arrayByAddingObjectsFromArray:DPChatGPTStatusRows()];
}
