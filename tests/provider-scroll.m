#import "Patches/DiaChatModel/ProviderUI.h"
#import <CoreGraphics/CoreGraphics.h>
#include <assert.h>

@interface DPScrollTestDocument : NSView
@end
@implementation DPScrollTestDocument
- (BOOL)isFlipped { return YES; }
@end

@interface DPScrollTestPage : NSScrollView
@property NSUInteger received;
@property NSEvent *last;
@end
@implementation DPScrollTestPage
- (void)scrollWheel:(NSEvent *)event { self.received++; self.last = event; }
@end

static NSEvent *DPTestWheel(int delta) {
    CGEventRef event = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine, 1, delta);
    NSEvent *result = [NSEvent eventWithCGEvent:event]; CFRelease(event); return result;
}

int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    DPScrollTestPage *page = [[DPScrollTestPage alloc] initWithFrame:NSMakeRect(0, 0, 300, 400)];
    page.documentView = [[DPScrollTestDocument alloc] initWithFrame:NSMakeRect(0, 0, 300, 1400)];
    NSMutableArray *models = [NSMutableArray new];
    for (NSUInteger i = 0; i < 8; i++) [models addObject:[NSView new]];
    NSScrollView *list = (id)DPProviderModels(models);
    [page.documentView addSubview:list];
    list.frame = NSMakeRect(0, 200, 300, 230);
    // Control the document geometry without needing a visible Dia window.
    list.documentView = [[DPScrollTestDocument alloc] initWithFrame:NSMakeRect(0, 0, 300, 56)];
    NSEvent *down = DPTestWheel(-5), *up = DPTestWheel(5);
    [list scrollWheel:down]; [list scrollWheel:up];
    assert(page.received == 2 && page.last == up);

    list.documentView.frame = NSMakeRect(0, 0, 300, 800);
    [list.contentView scrollToPoint:NSMakePoint(0, 0)];
    [list scrollWheel:up]; assert(page.received == 3 && page.last == up);
    [list scrollWheel:down]; assert(page.received == 3);
    [list.contentView scrollToPoint:NSMakePoint(0, 570)];
    [list scrollWheel:down]; assert(page.received == 4 && page.last == down);
    [list scrollWheel:up]; assert(page.received == 4);
    [list.contentView scrollToPoint:NSMakePoint(0, 250)];
    [list scrollWheel:down]; [list scrollWheel:up];
    assert(page.received == 4);
    puts("PASS original wheel events reach the page for short lists and both boundaries; interior events stay with the model list");
} }
