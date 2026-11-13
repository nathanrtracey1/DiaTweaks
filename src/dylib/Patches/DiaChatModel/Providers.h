#import "StdPatch/StdPatch.h"
#import "Patches/AgentTransport/AgentRelay.h"

@interface DPChatProviders : NSObject
+ (NSArray<NSDictionary *> *)accounts;
+ (NSDictionary *)account:(NSString *)identifier;
+ (NSString *)save:(NSDictionary *)provider key:(NSString *)key;
+ (NSString *)remove:(NSString *)identifier;
+ (NSString *)visibility:(NSString *)identifier model:(NSString *)model shown:(BOOL)shown;
+ (NSString *)showAll:(NSString *)identifier shown:(BOOL)shown;
+ (NSString *)futureModels:(NSString *)identifier enabled:(BOOL)enabled;
+ (NSString *)addModel:(NSString *)identifier model:(NSString *)model;
+ (void)refresh:(NSString *)identifier force:(BOOL)force completion:(void (^)(NSString *))completion;
+ (NSDictionary *)snapshot:(NSString *)identifier;
+ (void)ensureApple;
+ (NSString *)status:(NSString *)identifier;
+ (id)run:(NSDictionary *)body provider:(NSDictionary *)provider delta:(void (^)(NSString *))delta
    completion:(void (^)(NSDictionary *, NSString *))completion;
@end

@interface DPProviderSession : NSObject
- (instancetype)initWithProvider:(NSDictionary *)provider;
- (void)start:(NSDictionary *)body chunk:(void (^)(NSString *))chunk calls:(void (^)(NSArray *))calls
    completion:(void (^)(NSString *))completion;
- (void)cancel;
@end

void DPProviderChanged(void);
void DPSetChatProvider(NSDictionary *provider, DPAgentFilter nativeFilter);
NSArray<NSView *> *DPProviderRows(void);
NSDictionary *DPSelectedChatProvider(void);
NSString *DPActiveChatChoice(void);
NSString *DPChatChoiceTitle(NSString *choice);
NSMenu *DPDiaChatModels(void);
NSString *DPChatWorkDirectory(NSDictionary *body, NSString *context);
NSString *DPAbsoluteChatPath(id value, NSString *directory);
BOOL DPPathInsideChat(NSString *file, NSString *work, BOOL mayCreate);
NSString *DPReportEntry(NSDictionary *input, NSString *work);
BOOL DPApproveCustomChatFile(NSDictionary *frame, NSDictionary *call, NSString *work, DPAgentReply reply);
@interface DPProviderManager : NSWindowController
+ (void)show;
@end
