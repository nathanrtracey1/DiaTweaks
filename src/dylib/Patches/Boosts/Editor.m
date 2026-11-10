#import "Patches/Boosts/Editor.h"

@implementation DPBoostEditor

- (instancetype)initWithDomain:(NSString *)domain {
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _domain = domain;
    NSDictionary *boost = DPBoostFor(domain) ?: DPCleanBoost(@{});
    _zaps = [boost[@"zaps"] mutableCopy];
    self.view = [self makeContent:boost];
    _popover = [NSPopover new];
    _popover.behavior = NSPopoverBehaviorApplicationDefined;  // See -popoverDidShow:.
    _popover.contentViewController = self;
    _popover.delegate = self;
    return self;
}

- (void)save {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(save) object:nil];
    self.dirty = NO;
    DPSaveBoost(self.domain, DPCleanBoost(@{
        @"enabled" : @(self.enabled.state == NSControlStateValueOn), @"zaps" : self.zaps.copy,
        @"font" : self.font.selectedItem.representedObject ?: @"", @"css" : self.css.string.copy, @"js" : self.js.string.copy,
    }));
}

- (void)changed:(id)sender { [self save]; }

- (void)textDidChange:(NSNotification *)notification {
    self.dirty = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(save) object:nil];
    [self performSelector:@selector(save) withObject:nil afterDelay:0.4];
}

// Each click on the page hides what's under it, until Escape or Done. The popover stays open meanwhile, listing them.
- (void)zap:(id)sender {
    if (self.zapping) return DPStopPicking(self.zapping);
    id contents = DPFrontContents();
    if (!contents || ![DPFrontDomain() isEqual:self.domain]) return NSBeep();  // The front tab is another site now.
    self.zapping = contents;
    [self showZapping];
    if (self.enabled.state != NSControlStateValueOn) {  // Zapping with the Boost off would hide nothing.
        self.enabled.state = NSControlStateValueOn;
        [self save];
    }
    [self.browserWindow makeKeyWindow];  // The page only follows the pointer while its window is key.
    __weak DPBoostEditor *weakSelf = self;
    DPPickElements(contents, ^(NSDictionary *zap) {
        DPBoostEditor *editor = weakSelf;
        NSDictionary *clean = [DPCleanBoost(@{ @"zaps" : @[ zap ] })[@"zaps"] firstObject];
        if (!editor || !clean) return;
        [editor.zaps addObject:clean];
        [editor save];
        [editor addZapRow:clean animated:YES];
    }, ^{
        weakSelf.zapping = nil;
        [weakSelf showZapping];
    });
}

// Sheets go on the browser window: the popover closes first, saving what's left.
- (void)importBoost:(id)sender {
    NSWindow *window = self.browserWindow;
    [self.popover close];
    DPImportBoost(window);
}

- (void)exportBoost:(id)sender {
    NSWindow *window = self.browserWindow;
    [self.popover close];
    DPExportBoost(self.domain, window);
}

- (void)deleteBoost:(id)sender {
    NSString *domain = self.domain;
    NSWindow *window = self.browserWindow;
    [self.popover close];
    NSAlert *alert = [NSAlert new];
    alert.messageText = [NSString stringWithFormat:@"Delete the Boost for %@?", domain];
    alert.informativeText = @"The site goes back to how it looks without it.";
    [alert addButtonWithTitle:@"Delete"].hasDestructiveAction = YES;
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) DPSaveBoost(domain, nil);
    }];
}

@end
