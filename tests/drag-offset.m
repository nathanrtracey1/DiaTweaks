#import "Patches/CompactTabRows/CompactTabRows.h"

// Stand-ins for Dia's sidebar list: its own drag methods accept every drag and place nothing.
@interface _TtC7TabList11TabListView : NSView
@end
@implementation _TtC7TabList11TabListView
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)info { return NSDragOperationMove; }
- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)info { return NSDragOperationMove; }
- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)info { return YES; }
- (BOOL)performDragOperation:(id<NSDraggingInfo>)info { return YES; }
@end

@interface _TtCC7TabList11TabListView14CollectionView : NSCollectionView
@end
@implementation _TtCC7TabList11TabListView14CollectionView
@end

@interface ArcDraggingWindow : NSWindow
@end
@implementation ArcDraggingWindow
- (BOOL)isVisible { return YES; }
@end

@interface Drag : NSObject
@property NSPoint draggingLocation;
@end
@implementation Drag
@end

#import "Patches/CompactTabRows/CompactTabRows.m"

static NSView *DPListIn(NSView *tabList, NSArray<NSArray<NSValue *> *> *moves) {
    NSCollectionView *list = [[NSClassFromString(@(DPDiaTabListCollection)) alloc] initWithFrame:NSMakeRect(0, 0, 200, 600)];
    list.collectionViewLayout = [NSCollectionViewFlowLayout new];
    DPSet(list.collectionViewLayout, &DPMovesKey, moves);
    [tabList addSubview:list];
    return tabList;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        DPHook(DPDiaTabList, @selector(draggingEntered:), (IMP)DPTabList_entered);
        DPHook(DPDiaTabList, @selector(draggingUpdated:), (IMP)DPTabList_updated);
        DPHook(DPDiaTabList, @selector(prepareForDragOperation:), (IMP)DPTabList_prepare);
        DPHook(DPDiaTabList, @selector(performDragOperation:), (IMP)DPTabList_perform);

        // A row 37 pt tall that Dia lays out 51 pt tall: a pointer in it is handed on as a point 14 pt further along.
        NSArray *moves = @[ @[ [NSValue valueWithRect:NSMakeRect(0, 100, 200, 37)], [NSValue valueWithRect:NSMakeRect(0, 100, 200, 51)] ] ];
        NSView *compacted = DPListIn([[NSClassFromString(@(DPDiaTabList)) alloc] initWithFrame:NSMakeRect(0, 0, 200, 600)], moves);
        NSView *plain = DPListIn([[NSClassFromString(@(DPDiaTabList)) alloc] initWithFrame:NSMakeRect(0, 0, 200, 600)], nil);

        NSWindow *dragging = [[ArcDraggingWindow alloc] initWithContentRect:NSMakeRect(0, 0, 200, 100) styleMask:NSWindowStyleMaskBorderless
                                                                    backing:NSBackingStoreBuffered defer:YES];
        NSView *tab = [[NSView alloc] initWithFrame:NSMakeRect(10, 20, 100, 30)];
        [dragging.contentView addSubview:tab];
        Drag *drag = [Drag new];
        drag.draggingLocation = NSMakePoint(50, 480);
        id<NSDraggingInfo> info = (id<NSDraggingInfo>)drag;
        NSPoint home = tab.frame.origin;

        [(id<NSDraggingDestination>)compacted draggingUpdated:info];
        NSCAssert(NSMinY(tab.frame) != home.y, @"over compacted rows the tab is put back under the pointer");
        tab.frame = NSMakeRect(home.x, home.y, 100, 30);

        NSCAssert([(id<NSDraggingDestination>)compacted prepareForDragOperation:info] && [(id<NSDraggingDestination>)compacted performDragOperation:info], @"drops go through");
        [(id<NSDraggingDestination>)plain draggingEntered:info];
        NSCAssert(NSEqualPoints(tab.frame.origin, home), @"a drop's offset isn't applied to the next drag");

        [(id<NSDraggingDestination>)compacted draggingUpdated:info];
        tab.frame = NSMakeRect(home.x, home.y, 100, 30);
        [(id<NSDraggingDestination>)compacted prepareForDragOperation:info];
        [(id<NSDraggingDestination>)plain draggingUpdated:info];
        NSCAssert(NSEqualPoints(tab.frame.origin, home), @"nor one a drop left after its first step");
        puts("all drag offset checks passed");
    }
}
