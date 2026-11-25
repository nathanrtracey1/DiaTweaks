#import "Patches/Boosts/Editor.h"

// Arc's color pad: a dotted square in a ring, with a large handle for the page's ground and a small one, which follows
// it, for its text. Both are grey until a color is picked.
static const CGFloat DPRing = 7, DPHandle = 15, DPSmallHandle = 10;

// The palette's ground or text color. Its lightness is HSL, as in CSS; NSColor takes HSB.
static NSColor *DPSwatch(NSDictionary *color, BOOL text) {
    if (!color) return [NSColor colorWithWhite:text ? 0.2 : 0.45 alpha:1];
    NSDictionary *p = DPBoostPalette(color);
    double s = [p[text ? @"ts" : @"s"] doubleValue] / 100, l = [p[text ? @"t" : @"b"] doubleValue];
    double v = l + s * MIN(l, 1 - l);
    return [NSColor colorWithHue:[p[@"h"] doubleValue] / 360 saturation:v ? 2 * (1 - l / v) : 0 brightness:v alpha:1];
}

static void DPDrawHandle(NSPoint at, CGFloat radius, NSColor *color) {
    NSRect rect = NSMakeRect(at.x - radius, at.y - radius, radius * 2, radius * 2);
    [NSGraphicsContext saveGraphicsState];
    NSShadow *shadow = [NSShadow new];
    shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.3];
    shadow.shadowBlurRadius = 3;
    shadow.shadowOffset = NSMakeSize(0, -1);
    [shadow set];
    [NSColor.whiteColor setFill];
    [[NSBezierPath bezierPathWithOvalInRect:rect] fill];
    [NSGraphicsContext restoreGraphicsState];
    [color setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(rect, 2.5, 2.5)] fill];
}

@implementation DPBoostColorPad

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.accessibilityElement = YES;
    self.accessibilityRole = NSAccessibilityColorWellRole;
    self.accessibilityLabel = @"Color";
    [self.heightAnchor constraintEqualToAnchor:self.widthAnchor].active = YES;
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)setColor:(NSDictionary *)color {
    _color = [color copy];
    self.needsDisplay = YES;
}

// Where the large handle's middle can go.
- (NSRect)field { return NSInsetRect(self.bounds, DPRing + DPHandle + 3, DPRing + DPHandle + 3); }

- (void)drawRect:(NSRect)dirty {
    NSColor *ground = DPSwatch(self.color, NO), *text = DPSwatch(self.color, YES);
    NSBezierPath *ring = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:20 yRadius:20];
    [[[NSGradient alloc] initWithColors:@[ text, ground, text ]] drawInBezierPath:ring angle:60];
    NSRect inside = NSInsetRect(self.bounds, DPRing, DPRing);
    [NSColor.textBackgroundColor setFill];
    [[NSBezierPath bezierPathWithRoundedRect:inside xRadius:13 yRadius:13] fill];
    [[NSColor.labelColor colorWithAlphaComponent:0.12] setFill];
    for (CGFloat y = NSMinY(inside) + 6; y < NSMaxY(inside) - 5; y += 5)
        for (CGFloat x = NSMinX(inside) + 6; x < NSMaxX(inside) - 5; x += 5) NSRectFillUsingOperation(NSMakeRect(x, y, 1, 1), NSCompositingOperationSourceOver);

    NSRect field = self.field;
    NSPoint at = NSMakePoint(NSMinX(field) + NSWidth(field) * 0.8, NSMidY(field));
    if (self.color) at = NSMakePoint(NSMinX(field) + NSWidth(field) * [self.color[@"hue"] doubleValue] / 360, NSMaxY(field) - NSHeight(field) * [self.color[@"sat"] doubleValue] / 100);
    NSRect room = NSInsetRect(inside, DPSmallHandle + 2, DPSmallHandle + 2);  // The small one sits under it, to its left, and stays in.
    DPDrawHandle(NSMakePoint(MAX(at.x - 10, NSMinX(room)), MIN(at.y + 22, NSMaxY(room))), DPSmallHandle, text);
    DPDrawHandle(at, DPHandle, ground);
}

- (void)pick:(NSEvent *)event done:(BOOL)done {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSRect field = self.field;
    double x = MIN(MAX((point.x - NSMinX(field)) / NSWidth(field), 0), 1), y = MIN(MAX((NSMaxY(field) - point.y) / NSHeight(field), 0), 1);
    if (self.picked) self.picked(round(x * 360), round(y * 100), done);
}

- (void)mouseDown:(NSEvent *)event { [self pick:event done:NO]; }
- (void)mouseDragged:(NSEvent *)event { [self pick:event done:NO]; }
- (void)mouseUp:(NSEvent *)event { [self pick:event done:YES]; }

@end
