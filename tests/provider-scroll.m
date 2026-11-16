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
    NSScrollView *list = (id)DPProviderModels(@[[NSView new]]);
    [page.documentView addSubview:list];
    list.frame = NSMakeRect(0, 200, 300, 230);
    // Control the document geometry without needing a visible Dia window.
    struct { CGFloat height, offset; int delta; BOOL forwards; } cases[] = {
        {56, 0, -5, YES}, {56, 0, 5, YES},       // A single model never traps the wheel.
        {800, 0, 5, YES}, {800, 0, -5, NO},     // Top boundary.
        {800, 570, -5, YES}, {800, 570, 5, NO}, // Bottom boundary.
        {800, 250, -5, NO}, {800, 250, 5, NO},  // Interior.
    };
    list.documentView = [DPScrollTestDocument new];
    for (NSUInteger i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
        list.documentView.frame = NSMakeRect(0, 0, 300, cases[i].height);
        [list.contentView scrollToPoint:NSMakePoint(0, cases[i].offset)];
        page.received = 0; page.last = nil;
        NSEvent *event = DPTestWheel(cases[i].delta);
        [list scrollWheel:event];
        assert(page.received == (cases[i].forwards ? 1 : 0));
        assert(page.last == (cases[i].forwards ? event : nil));
    }
    puts("PASS wheel-event forwarding for short lists, boundaries and interior positions");
} }
