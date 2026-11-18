#import "Providers.h"

@interface DPSafetyReview : NSObject
@property DPProviderSession *session;
@property NSMutableString *buffer, *text;
@property BOOL ended, invalid, finished;
@property (copy) void (^completion)(NSString *decision, NSString *reason);
- (void)append:(NSString *)chunk;
- (void)finish:(NSString *)problem;
- (void)cancel;
@end

NSDictionary *DPSafetyBody(NSDictionary *body, NSDictionary *tool);
void DPCheckCustomSafety(NSDictionary *provider, NSDictionary *body, DPSafetyReview *review);
