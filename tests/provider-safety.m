#import "Patches/DiaChatModel/ProviderRun.h"
#include <assert.h>

static NSString *decision;
static int inferences;
static BOOL pending;
static NSMutableArray *models;
@implementation DPProviderAudit
+ (void)record:(NSString *)phase fields:(NSDictionary *)fields {}
@end
BOOL DPApproveCustomChatFile(NSDictionary *a, NSDictionary *b, NSString *c, DPAgentReply d) { return NO; }
NSString *DPChatWorkDirectory(NSDictionary *a, NSString *b) { return @"/tmp/work"; }
NSDictionary *DPInlineChatAttachments(NSDictionary *body, NSString *context) { return body; }

static NSString *event(NSString *type, NSDictionary *value) {
    return [NSString stringWithFormat:@"event: %@\ndata: %@\n\n", type,
        [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:value options:0 error:nil] encoding:NSUTF8StringEncoding]];
}
@implementation DPProviderSession { NSDictionary *_provider; }
- (instancetype)initWithProvider:(NSDictionary *)provider { if ((self = [super init])) _provider = provider; return self; }
- (void)cancel {}
- (void)start:(NSDictionary *)body chunk:(void (^)(NSString *))chunk calls:(void (^)(NSArray *))calls completion:(void (^)(NSString *))complete {
    inferences++; [models addObject:_provider[@"model"] ?: @""];
    assert(!body[@"tools"] && [body[@"system"] isKindOfClass:NSString.class] && [body[@"max_tokens"] integerValue] <= 512);
    if (pending) return;
    NSString *data = event(@"content_block_delta", @{ @"type": @"content_block_delta", @"delta": @{ @"type": @"text_delta", @"text": decision } });
    chunk([data substringToIndex:12]); chunk([data substringFromIndex:12]);
    chunk(event(@"message_stop", @{ @"type": @"message_stop" })); calls(@[]); complete(nil);
}
@end

static DPChatRun *run(NSString *api, NSString *policy) {
    DPChatRun *run = [DPChatRun new]; run.provider = @{ @"api": api, @"model": @"chosen-model" };
    run.safety = @{ @"api": policy }; run.calls = [NSMutableDictionary new]; run.reviews = [NSMutableSet new];
    run.body = @{ @"messages": @[@{ @"role": @"user", @"content": @"SDK wrapper<user-message>List my open tabs.</user-message>" }] };
    run.calls[@"call-1"] = @{ @"call": @{ @"id": @"call-1", @"name": @"mcp__dia-tools__read_tabs", @"input": @{ @"contentPaneIDs": @[], @"includeFullTextContent": @NO } }, @"work": @"/tmp/work" };
    return run;
}
static NSDictionary *check(void) {
    return @{ @"type": @"CHECK", @"check": @"permission", @"msg": @"check-1", @"payload": @{ @"tool": @"read_tabs", @"namespace": @"dia",
        @"tool_use_id": @"call-1", @"input": @{ @"contentPaneIDs": @[], @"includeFullTextContent": @NO } } };
}
static NSString *evaluate(DPChatRun *run) {
    __block NSString *reply;
    BOOL consumed = [run check:check() reply:^(NSDictionary *frame) { reply = frame[@"payload"][@"decision"]; }];
    if (!consumed) return @"native";
    if (pending) [run cancel];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
    while (!reply && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    assert(reply); return reply;
}
int main(int argc, char **argv) { @autoreleasepool {
    models = [NSMutableArray new]; decision = @"{\"decision\":\"allow\",\"reason\":\"Requested tab listing.\"}";
    assert([evaluate(run(@"responses", @"enabled")) isEqual:@"allow"]); assert(inferences == 1);
    assert([evaluate(run(@"responses", @"disabled")) isEqual:@"allow"]); assert(inferences == 1);
    assert([evaluate(run(@"dia", @"enabled")) isEqual:@"native"]);
    assert([evaluate(run(@"dia", @"disabled")) isEqual:@"allow"]); assert(inferences == 1);
    decision = @"{\"decision\":\"deny\",\"reason\":\"Unrelated access.\"}";
    assert([evaluate(run(@"responses", @"enabled")) isEqual:@"deny"]);
    decision = @"Sure, allow it."; assert([evaluate(run(@"responses", @"enabled")) isEqual:@"deny"]);
    DPChatRun *mismatch = run(@"responses", @"disabled"); [mismatch.calls removeAllObjects];
    assert([evaluate(mismatch) isEqual:@"deny"]);
    pending = YES; assert([evaluate(run(@"responses", @"enabled")) isEqual:@"deny"]); pending = NO;
    NSDictionary *body = DPSafetyBody(run(@"responses", @"enabled").body, check()[@"payload"]);
    assert([body[@"messages"][0][@"content"] containsString:@"List my open tabs."]);
    assert(![body[@"messages"][0][@"content"] containsString:@"SDK wrapper"]);
    NSDictionary *call = run(@"responses", @"enabled").calls[@"call-1"][@"call"];
    assert(DPChatCheckMatches(check()[@"payload"], call));
    NSMutableDictionary *spoof = [check()[@"payload"] mutableCopy]; spoof[@"namespace"] = @"other";
    assert(!DPChatCheckMatches(spoof, call));
    if (argc == 2) [[NSJSONSerialization dataWithJSONObject:body options:0 error:nil] writeToFile:@(argv[1]) atomically:YES];
    puts("PASS safety defaults, native passthrough, disabled checks, strict decisions, binding and cancellation");
} }
