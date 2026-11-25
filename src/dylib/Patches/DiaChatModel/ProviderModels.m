#import "ProviderUI.h"

@interface DPProviderModelList : NSStackView
@end
@implementation DPProviderModelList
- (BOOL)isFlipped { return YES; }
@end

@interface DPProviderModelScroll : NSScrollView
@end
@implementation DPProviderModelScroll
- (void)scrollWheel:(NSEvent *)event {
    NSRect document = self.documentView.bounds, visible = self.documentVisibleRect;
    CGFloat delta = event.scrollingDeltaY;
    BOOL fits = NSHeight(document) <= NSHeight(self.contentView.bounds) + 0.5;
    BOOL atTop = NSMinY(visible) <= NSMinY(document) + 0.5;
    BOOL atBottom = NSMaxY(visible) >= NSMaxY(document) - 0.5;
    NSScrollView *page = self.superview.enclosingScrollView;
    if (page && (fits || (delta > 0 && atTop) || (delta < 0 && atBottom))) [page scrollWheel:event];
    else [super scrollWheel:event];
}
@end

NSView *DPProviderModels(NSArray<NSView *> *models) {
    NSStackView *list = [DPProviderModelList new];
    list.orientation = NSUserInterfaceLayoutOrientationVertical; list.spacing = 0;
    for (NSView *model in models) {
        [list addArrangedSubview:model];
        [model.widthAnchor constraintEqualToAnchor:list.widthAnchor].active = YES;
    }
    NSScrollView *scroll = [DPProviderModelScroll new];
    scroll.documentView = list; scroll.drawsBackground = NO; scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.verticalScrollElasticity = NSScrollElasticityNone;
    list.translatesAutoresizingMaskIntoConstraints = NO;
    [list.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active = YES;
    [scroll.heightAnchor constraintEqualToConstant:MIN(models.count * 56, 230)].active = YES;
    return scroll;
}
