#import "Providers.h"
#import "Settings/Settings.h"

@interface DPProviderList : NSStackView
@property NSView *editor;
- (void)reload;
- (void)edit:(NSDictionary *)provider;
@end
@interface DPProviderEditor : NSStackView
@property NSDictionary *provider;
@property NSPopUpButton *preset, *format;
@property NSTextField *name, *base, *problem;
@property NSSecureTextField *key;
@property NSButton *clear, *advanced;
@property NSStackView *form;
@property (copy) void (^finished)(void);
- (instancetype)initWithProvider:(NSDictionary *)provider finished:(void (^)(void))finished;
- (void)preset:(id)sender;
- (void)save:(id)sender;
- (void)cancel:(id)sender;
- (void)connect:(id)sender;
- (void)disclose:(id)sender;
- (void)render;
@end
@interface DPProviderCard : NSStackView
@property NSDictionary *provider;
@property NSTextField *status;
@property NSTextField *modelID;
- (instancetype)initWithProvider:(NSDictionary *)provider;
- (void)problem:(NSString *)message;
- (void)edit:(id)sender;
- (void)refresh:(id)sender;
- (void)signOut:(id)sender;
- (void)all:(id)sender;
- (void)none:(id)sender;
- (void)future:(NSButton *)sender;
- (void)model:(NSButton *)sender;
@end
@interface DPProviderCard (Editing)
- (void)remove:(id)sender;
- (void)manual:(id)sender;
@end
NSStackView *DPProviderColumn(NSArray<NSView *> *views);
NSView *DPProviderModels(NSArray<NSView *> *models);
void DPProviderStretch(NSView *view);
