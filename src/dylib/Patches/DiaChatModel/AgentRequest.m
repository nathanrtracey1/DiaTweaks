#import <Foundation/Foundation.h>

NSString *DPSelectedDiaChatModel(NSString *choice, NSArray<NSString *> *models, BOOL fallback) {
    if (!choice.length || [choice isEqual:@"dia-default"]) return nil;
    return !fallback || [models containsObject:choice] ? choice : nil;
}

NSData *DPChatAgentRequest(NSData *line, NSString *model) {
    if (!model.length) return line;
    NSMutableDictionary *message = [NSJSONSerialization JSONObjectWithData:line options:NSJSONReadingMutableContainers error:nil];
    if (![message isKindOfClass:NSMutableDictionary.class] || ![message[@"type"] isEqual:@"RUN"]) return line;
    NSMutableDictionary *run = message[@"payload"] ?: message;
    if (![run isKindOfClass:NSMutableDictionary.class] || ![run[@"agent"] isEqual:@"default"] ||
        ![run[@"prompt"] isKindOfClass:NSString.class]) return line;
    NSMutableDictionary *spec = run[@"spec_override"];
    if (![spec isKindOfClass:NSMutableDictionary.class]) return line;
    NSMutableDictionary *settings = spec[@"settings"];
    if (![settings isKindOfClass:NSMutableDictionary.class] || ![settings[@"model"] isKindOfClass:NSString.class]) return line;
    NSMutableDictionary *env = settings[@"env"];
    if (env && ![env isKindOfClass:NSMutableDictionary.class]) return line;
    settings[@"model"] = model;
    settings[@"env"] = env ?: (env = [NSMutableDictionary new]);
    env[@"DIA_EXPLICIT_MODEL_SELECTION"] = @"true";
    return [NSJSONSerialization dataWithJSONObject:message options:0 error:nil] ?: line;
}
