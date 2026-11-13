#import "Providers.h"

@interface DPChatRun : NSObject
@property NSDictionary *provider;
@property DPProviderSession *session;
@property NSString *context;
@property NSMutableDictionary<NSString *, NSDictionary *> *calls;
- (BOOL)consume:(NSDictionary *)message reply:(DPAgentReply)reply;
@end
