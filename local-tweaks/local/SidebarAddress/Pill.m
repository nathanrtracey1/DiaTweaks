#import "SidebarAddress.h"

static const CGFloat DPPillTextInset = 10;

@interface DPSidebarPill : NSView
@property (nonatomic) NSTextField *label;
@property (nonatomic) BOOL hovered;
@end

@implementation DPSidebarPill

- (instancetype)init {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 10;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.accessibilityLabel = @"Address";
    _label = [NSTextField labelWithString:@""];
    _label.font = [NSFont systemFontOfSize:13];
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_label];
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (BOOL)mouseDownCanMoveWindow { return NO; }
- (NSView *)hitTest:(NSPoint)point { return [super hitTest:point] ? self : nil; }
- (void)resetCursorRects { [self addCursorRect:self.bounds cursor:NSCursor.IBeamCursor]; }
- (void)mouseDown:(NSEvent *)event { DPEditAddress(self.window); }

- (void)updateTrackingAreas {
    for (NSTrackingArea *area in self.trackingAreas) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
    [super updateTrackingAreas];
}

- (void)mouseEntered:(NSEvent *)event { self.hovered = YES; self.needsDisplay = YES; }
- (void)mouseExited:(NSEvent *)event { self.hovered = NO; self.needsDisplay = YES; }

- (BOOL)wantsUpdateLayer { return YES; }

// Here, not when the hover changes: labelColor has to be resolved again when the appearance changes.
- (void)updateLayer {
    self.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:self.hovered ? 0.12 : 0.07].CGColor;
}

- (void)layout {
    [super layout];
    CGFloat height = ceil(self.label.intrinsicContentSize.height);
    self.label.frame = NSMakeRect(DPPillTextInset, round((NSHeight(self.bounds) - height) / 2), MAX(0, NSWidth(self.bounds) - 2 * DPPillTextInset), height);
}

- (void)refresh {
    NSString *address = DPToolbarAddress(DPToolbarFor(self.window));
    NSString *shown = address.length ? address : @"Search or enter address";
    if (![self.label.stringValue isEqualToString:shown]) self.label.stringValue = shown;
    NSColor *color = address.length ? NSColor.labelColor : NSColor.secondaryLabelColor;
    if (![self.label.textColor isEqual:color]) self.label.textColor = color;
    self.toolTip = address.length ? address : nil;
}

@end

NSView *DPMakeSidebarPill(void) { return [DPSidebarPill new]; }
BOOL DPIsSidebarPill(NSView *view) { return [view isKindOfClass:DPSidebarPill.class]; }
void DPRefreshSidebarPill(NSView *pill) { if (DPIsSidebarPill(pill)) [(DPSidebarPill *)pill refresh]; }
