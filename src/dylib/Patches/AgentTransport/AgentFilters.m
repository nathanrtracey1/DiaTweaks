#import "AgentRelay.h"
#import "AgentSocket.h"

static NSMutableDictionary<NSString *, NSArray *> *DPRules;

static NSObject *AgentFiltersLock(void) {
    static NSObject *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [NSObject new]; });
    return lock;
}

void DPSetAgentFilters(NSString *key, DPAgentFilter requests, DPAgentFilter responses) {
    DPInstallAgentTransport();
    @synchronized (AgentFiltersLock()) {
        DPRules = DPRules ?: [NSMutableDictionary new];
        if (requests || responses) DPRules[key] = @[ [requests copy] ?: NSNull.null, [responses copy] ?: NSNull.null ];
        else [DPRules removeObjectForKey:key];
    }
}

BOOL DPAgentFiltersActive(void) {
    @synchronized (AgentFiltersLock()) { return DPRules.count != 0; }
}

NSArray *DPAgentFilters(BOOL requests) {
    @synchronized (AgentFiltersLock()) {
        NSMutableArray *filters = [NSMutableArray new];
        for (NSString *key in [DPRules.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            id filter = DPRules[key][requests ? 0 : 1];
            if (filter != NSNull.null) [filters addObject:filter];
        }
        return filters;
    }
}

static DPAgentEnvironment DPEnvironment;
static DPAgentConnected DPConnected;

void DPSetAgentEnvironment(DPAgentEnvironment configure) {
    @synchronized (AgentFiltersLock()) { DPEnvironment = [configure copy]; }
}

void DPSetAgentConnected(DPAgentConnected connected) {
    @synchronized (AgentFiltersLock()) { DPConnected = [connected copy]; }
}

NSDictionary<NSString *, NSString *> *DPAgentEnvironmentChanges(NSString *directory, NSDictionary<NSString *, NSString *> *original) {
    DPAgentEnvironment configure;
    @synchronized (AgentFiltersLock()) { configure = DPEnvironment; }
    return configure ? configure(directory, original) : nil;
}

DPAgentConnected DPAgentConnectedHandler(void) {
    @synchronized (AgentFiltersLock()) { return DPConnected; }
}
