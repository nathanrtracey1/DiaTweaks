#import "Patches/DiaChatModel/ProviderRun.h"
#include <assert.h>

static DPAgentFilter requests, responses;
static NSMutableArray *models;
static int cancellations;
void DPSetAgentFilters(NSString *key, DPAgentFilter a, DPAgentFilter b) { requests = a; responses = b; }
BOOL DPApproveCustomChatFile(NSDictionary *a, NSDictionary *b, NSString *c, DPAgentReply d) { return NO; }
NSString *DPChatWorkDirectory(NSDictionary *a, NSString *b) { return nil; }
@implementation DPProviderSession {
    NSDictionary *_provider;
    BOOL _cancelled;
}
- (instancetype)initWithProvider:(NSDictionary *)provider { if ((self = [super init])) _provider = provider; return self; }
- (void)cancel { _cancelled = YES; cancellations++; }
- (void)start:(NSDictionary *)body chunk:(void (^)(NSString *))chunk calls:(void (^)(NSArray *))calls completion:(void (^)(NSString *))complete {
    if (_cancelled) { complete(@"cancelled"); return; }
    [models addObject:_provider[@"model"]]; calls(@[]); chunk(@"data: fixture\n\n"); complete(nil);
}
@end

static NSData *frame(NSDictionary *value) { return [NSJSONSerialization dataWithJSONObject:value options:0 error:nil]; }
static void run(NSString *message, NSString *handler) {
    NSDictionary *request = @{ @"type": @"RUN", @"msg": message, @"payload": @{ @"agent": @"default", @"prompt": @"hi",
        @"spec_override": @{ @"settings": @{ @"model": @"native" } } } };
    assert(requests(frame(request), ^(NSDictionary *reply) {}).length);
    responses(frame(@{ @"type": @"ACK", @"msg": message, @"success": @YES, @"payload": @{ @"handler": handler } }), ^(NSDictionary *reply) {});
}
static void infer(NSString *handler) {
    __block BOOL got = NO;
    NSData *output = responses(frame(@{ @"type": @"LLM_REQUEST", @"handler": handler, @"msg": @"inference",
        @"payload": @{ @"endpoint": @"messages", @"body": @{ @"messages": @[] } } }), ^(NSDictionary *reply) { got = YES; });
    assert(!output && got);
}
int main(void) { @autoreleasepool {
    models = [NSMutableArray new];
    DPSetChatProvider(@{ @"api": @"responses", @"model": @"first" }, nil); run(@"1", @"one");
    DPSetChatProvider(@{ @"api": @"responses", @"model": @"second" }, nil); run(@"2", @"two");
    infer(@"one"); infer(@"two");
    assert(([models isEqual:@[@"first", @"second"]]));
    requests(frame(@{ @"type": @"CANCEL", @"handler": @"one" }), ^(NSDictionary *reply) {});
    assert(cancellations == 1);
    DPAgentFilter native = ^NSData *(NSData *line, DPAgentReply reply) { return line; };
    DPSetChatProvider(nil, native);
    infer(@"two"); assert(models.count == 3);
    NSData *unrelated = frame(@{ @"type": @"EVENT", @"handler": @"other" });
    assert(responses(unrelated, ^(NSDictionary *reply) {}) == unrelated);
    responses(frame(@{ @"type": @"DONE", @"handler": @"two" }), ^(NSDictionary *reply) {});
    assert(requests == native && !responses);

    DPSetChatProvider(@{ @"api": @"responses", @"model": @"second" }, native);
    run(@"3", @"three");
    DPSetChatProvider(nil, nil);
    assert(!requests && !responses && cancellations == 3);
    puts("PASS per-run snapshots, concurrent models, cancellation, native handoff and unrelated frames");
} }
