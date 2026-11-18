#import "Patches/Peek/Peek.h"
#import "StdPatch/Hook.m"

DPPatch DPPeek = { .on = YES };
static DPPeekCard *card;
static NSPoint pointer;
DPPeekCard *DPPeekCardIn(NSWindow *window) { return card.window == window ? card : nil; }
@implementation DPPeekCard
- (NSRect)cardFrame { return self.bounds; }
- (void)close:(DPPeekExit)exit { [self removeFromSuperview]; }
- (void)handOver { [self removeFromSuperview]; }
@end

@interface CursorWindow : NSWindow
@end
@implementation CursorWindow
- (NSPoint)mouseLocationOutsideOfEventStream { return pointer; }
@end

@interface RenderWidgetHostViewCocoa : NSView
@property BOOL allowed;
@property NSMutableArray<NSValue *> *rects;
@end
@implementation RenderWidgetHostViewCocoa
- (BOOL)shouldChangeCurrentCursor { return self.allowed; }
- (void)addCursorRect:(NSRect)rect cursor:(NSCursor *)cursor { [self.rects addObject:[NSValue valueWithRect:rect]]; }
@end

#import "Patches/Peek/Cursor.m"

static RenderWidgetHostViewCocoa *Page(NSView *parent, NSRect frame) {
    RenderWidgetHostViewCocoa *page = [[RenderWidgetHostViewCocoa alloc] initWithFrame:frame];
    page.allowed = YES;
    page.rects = [NSMutableArray new];
    [parent addSubview:page];
    return page;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        DPPeekInstallCursor();
        NSWindow *window = [[CursorWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
            styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        RenderWidgetHostViewCocoa *under = Page(window.contentView, window.contentView.bounds);
        pointer = NSMakePoint(300, 300);
        NSCAssert(under.shouldChangeCurrentCursor, @"no Peek preserves Chromium's answer");
        card = [[DPPeekCard alloc] initWithFrame:NSMakeRect(100, 100, 600, 400)];
        [window.contentView addSubview:card];
        RenderWidgetHostViewCocoa *peek = Page(card, NSMakeRect(50, 50, 500, 300));
        NSCAssert(!under.shouldChangeCurrentCursor && peek.shouldChangeCurrentCursor, @"only the front page may set the cursor");
        peek.allowed = NO;
        NSCAssert(!peek.shouldChangeCurrentCursor, @"Chromium's inactive/menu/hidden-cursor checks still apply");
        peek.allowed = YES;
        pointer = NSMakePoint(120, 120);
        NSCAssert(!under.shouldChangeCurrentCursor && !peek.shouldChangeCurrentCursor, @"dimmed margins belong to neither page");
        NSView *toolbar = [[NSView alloc] initWithFrame:NSMakeRect(50, 250, 500, 100)];
        [card addSubview:toolbar];
        pointer = NSMakePoint(300, 400);
        NSCAssert(!peek.shouldChangeCurrentCursor, @"toolbar above Peek keeps its own cursor");
        pointer = NSMakePoint(50, 50);
        NSCAssert(under.shouldChangeCurrentCursor, @"uncovered panes retain cursor updates");
        [under addCursorRect:under.bounds cursor:NSCursor.IBeamCursor];
        CGFloat area = 0;
        for (NSValue *value in under.rects) {
            NSRect rect = value.rectValue;
            NSCAssert(NSIsEmptyRect(NSIntersectionRect(rect, card.frame)), @"background cursor rectangles never cover Peek");
            area += NSWidth(rect) * NSHeight(rect);
        }
        NSCAssert(area == 800 * 600 - 600 * 400, @"all uncovered cursor area is preserved");
        [peek addCursorRect:peek.bounds cursor:NSCursor.pointingHandCursor];
        NSCAssert(peek.rects.count == 1 && NSEqualRects(peek.rects[0].rectValue, peek.bounds), @"Peek keeps its renderer cursor rectangles");
        [under.rects removeAllObjects];
        DPPeek.on = NO;
        pointer = NSMakePoint(300, 300);
        NSCAssert(under.shouldChangeCurrentCursor, @"with Peek off the page keeps Chromium's answer");
        [under addCursorRect:under.bounds cursor:NSCursor.IBeamCursor];
        NSCAssert(under.rects.count == 1 && NSEqualRects(under.rects[0].rectValue, under.bounds), @"with Peek off cursor rectangles pass through");
        DPPeek.on = YES;
        [under.rects removeAllObjects];
        [card removeFromSuperview];
        NSCAssert(under.shouldChangeCurrentCursor, @"closing Peek restores immediate updates");
        [under addCursorRect:under.bounds cursor:NSCursor.IBeamCursor];
        NSCAssert(under.rects.count == 1 && NSEqualRects(under.rects[0].rectValue, under.bounds), @"closing Peek restores full cursor rectangles");
        puts("all Peek cursor checks passed");
    }
}
