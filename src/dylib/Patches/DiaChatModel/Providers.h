#import "StdPatch/StdPatch.h"
#import "Patches/AgentTransport/AgentRelay.h"

@interface DPProviderAudit : NSObject
+ (void)record:(NSString *)phase fields:(NSDictionary *)fields;
@end

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
+ (NSString *)brand:(NSDictionary *)provider;
+ (NSString *)preset:(NSDictionary *)provider;
@end

@interface DPProviderSession : NSObject
- (instancetype)initWithProvider:(NSDictionary *)provider;
- (void)start:(NSDictionary *)body chunk:(void (^)(NSString *))chunk calls:(void (^)(NSArray *))calls
    completion:(void (^)(NSString *))completion;
- (void)cancel;
@end

void DPProviderChanged(void);
void DPSetChatProvider(NSDictionary *provider, DPAgentFilter nativeFilter);
void DPCancelChatAccount(NSString *identifier);
NSButton *DPChatGPTButton(void);
NSImageView *DPProviderIcon(NSDictionary *provider);
NSImage *DPProviderLogo(NSString *brand);
void DPRefreshChatGPTStatus(void);
void DPInstallChatGPTPage(void);
void DPInstallChatModelErrors(void);
void DPSetChatModelErrorAction(BOOL enabled);
void DPOpenChatModelSettings(void);
@interface DPChatGPT : NSObject
+ (void)start:(NSString *)identifier completion:(void (^)(NSString *))completion;
+ (void)cancel;
+ (void)showWelcome;
+ (void)signOut:(NSString *)identifier completion:(void (^)(NSString *))completion;
@end
NSArray<NSView *> *DPProviderRows(void);
NSDictionary *DPSelectedChatProvider(void);
NSDictionary *DPSelectedSafetyProvider(void);
void DPSetChatSafety(NSDictionary *provider);
NSString *DPActiveChatChoice(void);
NSString *DPChatChoiceTitle(NSString *choice);
NSMenu *DPDiaChatModels(void);
void DPAppendProviderModels(NSMenu *menu, NSArray<NSDictionary *> *accounts);
NSArray<NSView *> *DPChatGPTStatusRows(void);
void DPConnectChatGPT(NSString *identifier, NSWindow *parent);
void DPConnectChatGPTAccount(NSString *identifier, NSWindow *parent, void (^finished)(void));
NSString *DPChatWorkDirectory(NSDictionary *body, NSString *context);
NSString *DPAbsoluteChatPath(id value, NSString *directory);
BOOL DPPathInsideChat(NSString *file, NSString *work, BOOL mayCreate);
NSString *DPReportEntry(NSDictionary *input, NSString *work);
BOOL DPApproveCustomChatFile(NSDictionary *frame, NSDictionary *call, NSString *work, DPAgentReply reply);
BOOL DPChatCheckMatches(NSDictionary *payload, NSDictionary *call);
NSDictionary *DPInlineChatAttachments(NSDictionary *body, NSString *context);
NSString *DPChatReadRoot(NSString *file, NSString *work);
NSView *DPInlineProviderList(void);
