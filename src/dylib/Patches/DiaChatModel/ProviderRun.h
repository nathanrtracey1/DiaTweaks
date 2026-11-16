#import "Providers.h"
#import "SafetyReview.h"

@interface DPChatRun : NSObject
@property NSDictionary *provider;
@property DPProviderSession *session;
@property NSString *context;
@property NSMutableDictionary<NSString *, NSDictionary *> *calls;
@property NSDictionary *safety, *body;
@property NSMutableSet<DPSafetyReview *> *reviews;
@property BOOL cancelled;
- (BOOL)consume:(NSDictionary *)message reply:(DPAgentReply)reply;
@end
@interface DPChatRun (Safety)
- (BOOL)check:(NSDictionary *)message reply:(DPAgentReply)reply;
- (void)cancel;
@end
