#import "Providers.h"

void DPConnectChatGPTAccount(NSString *identifier, NSWindow *parent, void (^done)(void)) {
    NSAlert *progress = [NSAlert new]; progress.messageText = @"Continue with ChatGPT";
    progress.informativeText = @"Finish signing in in your browser.";
    [progress addButtonWithTitle:@"Cancel"];
    __block BOOL finished = NO;
    [progress beginSheetModalForWindow:parent completionHandler:^(NSModalResponse response) { if (!finished) [DPChatGPT cancel]; }];
    [DPChatGPT start:identifier completion:^(NSString *error) {
        finished = YES;
        if (progress.window.sheetParent) [progress.window.sheetParent endSheet:progress.window];
        [progress.window orderOut:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { NSAlert *alert = [NSAlert new]; alert.messageText = error; [alert beginSheetModalForWindow:parent completionHandler:nil]; }
            else { if (done) done(); [DPChatGPT showWelcome]; }
        });
    }];
}

void DPConnectChatGPT(NSString *identifier, NSWindow *parent) { DPConnectChatGPTAccount(identifier, parent, nil); }

@interface DPChatGPTControls : NSObject
- (void)connect:(id)sender;
- (void)usage:(id)sender;
- (void)signOut:(id)sender;
@end
@implementation DPChatGPTControls
- (void)connect:(NSView *)sender { DPConnectChatGPT(nil, sender.window); }
- (void)usage:(id)sender { [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://chatgpt.com/settings/usage"]]; }
- (void)signOut:(NSView *)sender {
    NSDictionary *provider = DPSelectedChatAccount();
    if (![provider[@"api"] isEqual:@"chatgpt"]) return;
    [DPChatGPT signOut:provider[@"id"] completion:^(NSString *error) {
        if (!error) return;
        NSAlert *alert = [NSAlert new]; alert.messageText = error;
        [alert beginSheetModalForWindow:sender.window completionHandler:nil];
    }];
}
@end

static DPChatGPTControls *DPChatGPTActions(void) {
    static DPChatGPTControls *controls;
    controls = controls ?: [DPChatGPTControls new]; return controls;
}

@interface DPChatGPTSignInButton : NSButton
@end
@implementation DPChatGPTSignInButton
- (NSSize)intrinsicContentSize {
    NSSize size = [super intrinsicContentSize];
    return NSMakeSize(size.width + 32, MAX(size.height + 24, 48));
}
@end

NSButton *DPChatGPTButton(void) {
    NSButton *button = [DPChatGPTSignInButton buttonWithTitle:@"Continue with ChatGPT" target:DPChatGPTActions() action:@selector(connect:)];
    button.bordered = NO; button.wantsLayer = YES;
    button.layer.backgroundColor = NSColor.blackColor.CGColor; button.layer.cornerRadius = 6;
    button.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium]; button.contentTintColor = NSColor.whiteColor;
    button.image = [DPProviderLogo(@"chatgpt") copy];
    button.image.size = NSMakeSize(20, 20); button.imagePosition = NSImageLeft; button.imageHugsTitle = YES;
    [button.heightAnchor constraintEqualToConstant:48].active = YES;
    [button setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    return button;
}
