#import "Providers.h"

@interface DPProviderManager ()
@property NSPopUpButton *accounts;
@property NSTableView *models;
@property NSButton *future;
@property NSTextField *status;
@property NSString *identifier;
- (void)reload;
- (void)problem:(NSString *)message;
@end
@interface DPProviderManager (Models) <NSTableViewDataSource, NSTableViewDelegate>
- (void)edit:(id)sender;
- (void)add:(id)sender;
- (void)remove:(id)sender;
- (void)refresh:(id)sender;
- (void)manual:(id)sender;
@end

void DPEditProvider(NSDictionary *existing, NSWindow *window, void (^finished)(NSString *));
NSStackView *DPProviderColumn(NSArray<NSView *> *views);
