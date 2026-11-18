#import "ProviderRun.h"

NSData *DPChatAgentRequest(NSData *, NSString *);
static NSDictionary *DPCurrentProvider, *DPCurrentSafety;
static NSMutableDictionary<NSString *, DPChatRun *> *DPPendingRuns, *DPActiveRuns;

static NSDictionary *DPProviderFrame(NSData *data) {
    id frame = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    return [frame isKindOfClass:NSMutableDictionary.class] ? frame : nil;
}

static NSData *DPProviderRequest(NSData *line, DPAgentReply reply) {
    NSMutableDictionary *message = (id)DPProviderFrame(line);
    NSString *handler = message[@"handler"];
    @synchronized (DPChatRun.class) {
        if ([message[@"type"] isEqual:@"CANCEL"] && [handler isKindOfClass:NSString.class]) {
            [DPActiveRuns[handler] cancel]; [DPActiveRuns removeObjectForKey:handler];
        }
        if (![message[@"type"] isEqual:@"RUN"]) return line;
        NSMutableDictionary *run = message[@"payload"] ?: message;
        [NSClassFromString(@"DPProviderAudit") record:@"route" fields:@{ @"agent": [run isKindOfClass:NSDictionary.class] ? run[@"agent"] ?: @"" : @"",
            @"api": DPCurrentProvider[@"api"] ?: @"", @"model": DPCurrentProvider[@"model"] ?: @"" }];
        if (![run isKindOfClass:NSMutableDictionary.class] || ![run[@"agent"] isEqual:@"default"] || !DPCurrentProvider) return line;
        NSString *msg = message[@"msg"];
        if (![msg isKindOfClass:NSString.class]) return nil;
        if (DPPendingRuns.count + DPActiveRuns.count >= 128) {
            reply(@{ @"type": @"ACK", @"msg": msg, @"success": @NO, @"payload": @{ @"error": @"Too many active custom-model runs." } }); return nil;
        }
        NSMutableDictionary *settings = [run[@"spec_override"] isKindOfClass:NSDictionary.class] ? run[@"spec_override"][@"settings"] : nil;
        if (![settings isKindOfClass:NSMutableDictionary.class]) {
            reply(@{ @"type": @"ACK", @"msg": msg, @"success": @NO, @"payload": @{ @"error": @"Dia’s agent request format changed." } }); return nil;
        }
        NSMutableDictionary *env = [settings[@"env"] isKindOfClass:NSMutableDictionary.class] ? settings[@"env"] : [NSMutableDictionary new];
        BOOL native = [DPCurrentProvider[@"api"] isEqual:@"dia"];
        if (!native) { env[@"ENABLE_TOOL_SEARCH"] = @"false"; settings[@"env"] = env; }
        NSData *rewritten = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
        if (!rewritten) return line;
        DPChatRun *state = [DPChatRun new];
        state.provider = DPCurrentProvider;
        state.safety = DPCurrentSafety ?: @{ @"api": @"enabled" };
        if (!native) state.session = [[DPProviderSession alloc] initWithProvider:state.provider];
        state.calls = [NSMutableDictionary new];
        state.reviews = [NSMutableSet new];
        DPPendingRuns[msg] = state;
        return native ? DPChatAgentRequest(rewritten, DPCurrentProvider[@"model"]) : rewritten;
    }
}

static NSData *DPProviderResponse(NSData *line, DPAgentReply reply) {
    NSDictionary *message = DPProviderFrame(line);
    NSString *msg = message[@"msg"], *handler = message[@"handler"];
    DPChatRun *run;
    @synchronized (DPChatRun.class) {
        if ([message[@"type"] isEqual:@"ACK"] && [msg isKindOfClass:NSString.class] && DPPendingRuns[msg]) {
            run = DPPendingRuns[msg]; [DPPendingRuns removeObjectForKey:msg];
            NSDictionary *payload = message[@"payload"];
            if ([payload isKindOfClass:NSDictionary.class] && [payload[@"handler"] isKindOfClass:NSString.class] && [message[@"success"] isEqual:@YES]) {
                run.context = [payload[@"context_id"] isKindOfClass:NSString.class] ? payload[@"context_id"] : @"";
                DPActiveRuns[payload[@"handler"]] = run;
            }
            return line;
        }
        if (![handler isKindOfClass:NSString.class]) return line;
        run = DPActiveRuns[handler];
        if ([message[@"type"] isEqual:@"DONE"]) { [run cancel]; [DPActiveRuns removeObjectForKey:handler]; return line; }
    }
    return run && [run consume:message reply:reply] ? nil : line;
}

void DPSetChatProvider(NSDictionary *provider) {
    @synchronized (DPChatRun.class) {
        DPCurrentProvider = [provider copy];
        if (!provider) for (DPChatRun *run in [DPActiveRuns.allValues arrayByAddingObjectsFromArray:DPPendingRuns.allValues ?: @[]]) [run cancel];
        if (!provider && !DPActiveRuns.count) return;
        DPPendingRuns = DPPendingRuns ?: [NSMutableDictionary new];
        DPActiveRuns = DPActiveRuns ?: [NSMutableDictionary new];
        DPSetAgentFilters(@"diaChatModel", ^NSData *(NSData *line, DPAgentReply reply) { return DPProviderRequest(line, reply); },
            ^NSData *(NSData *line, DPAgentReply reply) { return DPProviderResponse(line, reply); });
    }
}

void DPSetChatSafety(NSDictionary *provider) { @synchronized (DPChatRun.class) { DPCurrentSafety = [provider copy]; } }

void DPCancelChatAccount(NSString *identifier) {
    @synchronized (DPChatRun.class) {
        for (DPChatRun *run in [DPActiveRuns.allValues arrayByAddingObjectsFromArray:DPPendingRuns.allValues ?: @[]])
            if ([run.provider[@"id"] isEqual:identifier]) [run cancel];
    }
}
