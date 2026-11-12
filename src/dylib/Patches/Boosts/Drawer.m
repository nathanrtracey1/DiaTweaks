#import "Patches/Boosts/Editor.h"

static char DPHeightKey;  // A row's height, which opens and closes it.

// A group's line, one pixel thick. NSBox's separator keeps a 5-point frame and draws at its bottom, which left more
// room over each row's text than under it.
@interface DPBoostLine : NSView
@end

@implementation DPBoostLine
- (instancetype)init {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    return self;
}
- (NSSize)intrinsicContentSize { return NSMakeSize(NSViewNoIntrinsicMetric, 1 / (self.window.backingScaleFactor ?: 2)); }
- (void)viewDidChangeBackingProperties { [self invalidateIntrinsicContentSize]; }
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer { self.layer.backgroundColor = NSColor.separatorColor.CGColor; }
@end

@interface DPRowDrawer : NSObject
@property (nonatomic, weak) DPBoostEditor *editor;
@property (nonatomic, strong) NSView *row;
@property (nonatomic, strong) NSLayoutConstraint *height;
@property (nonatomic) CGFloat from, to;
@property (nonatomic) CFTimeInterval start;
@property (nonatomic, copy) void (^done)(void);
@end

@implementation DPRowDrawer
- (void)step:(CADisplayLink *)link {  // The link holds the drawer until it's invalidated.
    if (!self.start) self.start = link.timestamp;
    double t = self.editor.view.window ? MIN((link.timestamp - self.start) / 0.25, 1) : 1;
    double eased = t < 0.5 ? 4 * t * t * t : 1 - pow(2 - 2 * t, 3) / 2;
    self.height.constant = self.from + (self.to - self.from) * eased;
    self.row.alphaValue = self.to > self.from ? eased : 1 - eased;
    [self.editor fit];
    [self.editor.view layoutSubtreeIfNeeded];
    if (t < 1) return;
    [link invalidate];
    if (self.done) self.done();
}
@end

static CGFloat DPRowHeight(NSView *row) {
    CGFloat height = 0;
    for (NSView *view in row.subviews) height += view.fittingSize.height;
    return height;
}

NSView *DPDrawerRow(NSView *content, BOOL open) {
    NSView *line = [DPBoostLine new];
    NSView *row = [NSView new];
    row.wantsLayer = YES;
    row.layer.masksToBounds = YES;
    for (NSView *view in @[ line, content ]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:view];
    }
    NSLayoutConstraint *height = [row.heightAnchor constraintEqualToConstant:open ? DPRowHeight(row) : 0];
    [NSLayoutConstraint activateConstraints:@[
        [line.topAnchor constraintEqualToAnchor:row.topAnchor],
        [line.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12], [line.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
        [content.topAnchor constraintEqualToAnchor:line.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [content.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        height,
    ]];
    DPSet(row, &DPHeightKey, height);
    if (!open) row.alphaValue = 0;
    return row;
}

@implementation DPBoostEditor (Drawer)

// A row opens and closes like a drawer: its height goes to or from 0 with what's in it pinned to its top, so nothing in
// it moves while everything under it slides. The height, the fade and the popover's size all step here together, each
// frame, the popover's size taken at once.
- (void)open:(BOOL)open row:(NSView *)row done:(void (^)(void))done {
    DPRowDrawer *drawer = [DPRowDrawer new];
    drawer.editor = self;
    drawer.row = row;
    drawer.height = DPGet(row, &DPHeightKey);
    drawer.from = drawer.height.constant;
    drawer.to = open ? DPRowHeight(row) : 0;
    drawer.done = done;
    [[self.view displayLinkWithTarget:drawer selector:@selector(step:)] addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

@end
