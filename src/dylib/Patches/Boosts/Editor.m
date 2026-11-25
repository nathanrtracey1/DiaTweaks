#import "Patches/Boosts/Editor.h"

@implementation DPBoostEditor

- (instancetype)initWithDomain:(NSString *)domain {
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _domain = domain;
    _boost = [DPBoostFor(domain) ?: DPCleanBoost(@{}) mutableCopy];
    _zaps = [_boost[@"zaps"] mutableCopy];
    self.view = [self makeContent];
    [self showLook];
    _popover = [NSPopover new];
    _popover.behavior = NSPopoverBehaviorApplicationDefined;  // See -popoverDidShow:.
    _popover.contentViewController = self;
    _popover.delegate = self;
    return self;
}

- (void)save {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(save) object:nil];
    self.dirty = NO;
    [self.boost addEntriesFromDictionary:@{ @"zaps" : self.zaps.copy, @"css" : self.css.string.copy, @"js" : self.js.string.copy }];
    DPSaveBoost(self.domain, DPCleanBoost(self.boost));
}

// Typing saves once it has stopped for `delay`. A drag saves every `delay`, in the slider's run loop mode too.
- (void)saveIn:(NSTimeInterval)delay restarting:(BOOL)restart {
    if (self.dirty && !restart) return;
    self.dirty = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(save) object:nil];
    [self performSelector:@selector(save) withObject:nil afterDelay:delay inModes:@[ NSRunLoopCommonModes ]];
}

- (void)textDidChange:(NSNotification *)notification { [self saveIn:0.4 restarting:YES]; }

- (void)fit {
    NSSize size = self.view.fittingSize;
    if (NSEqualSizes(size, self.popover.contentSize)) return;
    self.popover.animates = NO;  // Its own resizing runs on its own clock and jolts its top.
    self.popover.contentSize = size;
    self.popover.animates = YES;
}

- (void)closeEditor:(id)sender { [self.popover close]; }

- (void)toggleOn:(id)sender {
    self.boost[@"enabled"] = @(![self.boost[@"enabled"] boolValue]);
    self.onItem.state = [self.boost[@"enabled"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    [self save];
}

// Each click on the page hides what's under it, until Escape or Zap again. The popover stays open meanwhile, listing them.
- (void)zap:(id)sender {
    if (self.zapping) return DPStopPicking(self.zapping);
    id contents = DPFrontContents();
    if (!contents || ![DPFrontDomain() isEqual:self.domain]) return NSBeep();  // The front tab is another site now.
    self.zapping = contents;
    [self showZapping];
    if (![self.boost[@"enabled"] boolValue]) [self toggleOn:nil];  // Zapping with the Boost off would hide nothing.
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
