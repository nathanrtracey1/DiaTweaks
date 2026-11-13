#import "SiteSearch.h"

static char DPGlowKey;

// The bar's rounded shape: the nearest view above the field that rounds its corners.
static NSView *DPRoundedBar(NSView *text) {
    for (NSView *view = text.superview; view; view = view.superview)
        if (view.layer.cornerRadius >= 10) return view;
    return nil;
}

// Fits the glow's parts to the bar, which grows and shrinks as the suggestions come and go.
static void DPFitGlow(CALayer *glow, CALayer *bar) {
    if (CGRectEqualToRect(glow.frame, bar.bounds) && [[glow valueForKey:@"DPRadius"] doubleValue] == bar.cornerRadius) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    glow.frame = bar.bounds;
    [glow setValue:@(bar.cornerRadius) forKey:@"DPRadius"];
    for (CALayer *part in glow.sublayers) {
        part.frame = glow.bounds;
        CAShapeLayer *edge = (CAShapeLayer *)part.mask;
        if (![edge isKindOfClass:CAShapeLayer.class]) {  // A ring of the steady glow.
            part.cornerRadius = bar.cornerRadius;
            continue;
        }
        edge.frame = part.bounds;
        CGFloat inset = edge.lineWidth / 2;
        CGRect rect = CGRectInset(part.bounds, inset, inset);
        CGFloat radius = MAX(0, bar.cornerRadius - inset);
        edge.path = CFAutorelease(CGPathCreateWithRoundedRect(rect, MIN(radius, CGRectGetWidth(rect) / 2), MIN(radius, CGRectGetHeight(rect) / 2), NULL));
        CGFloat side = hypot(CGRectGetWidth(part.bounds), CGRectGetHeight(part.bounds));
        for (CALayer *flow in part.sublayers) {
            flow.bounds = CGRectMake(0, 0, side, side);
            flow.position = CGPointMake(CGRectGetMidX(part.bounds), CGRectGetMidY(part.bounds));
        }
    }
    [CATransaction commit];
}

// The bar's edge lit in the site's color, so it's clear a site is being searched: a faint steady glow fading inward,
// with light flowing along it.
void DPShowGlow(NSTextView *text, NSColor *color) {
    CALayer *glow = DPGet(text, &DPGlowKey);
    if (!color) {
        DPSet(text, &DPGlowKey, nil);
        [CATransaction begin];
        [CATransaction setCompletionBlock:^{ [glow removeFromSuperlayer]; }];
        glow.opacity = 0;
        [CATransaction commit];
        return;
    }
    NSView *bar = DPRoundedBar(text);
    if (!bar.layer) return;
    if (!glow) {
        glow = [CALayer layer];
        glow.zPosition = 1000;
        glow.opacity = 0;
        CALayer *ring = [CALayer layer];
        ring.borderWidth = 8;
        ring.borderColor = [color colorWithAlphaComponent:0.05].CGColor;
        DPBreathe(ring);
        [glow addSublayer:ring];
        [glow addSublayer:DPFlow(color, 7, 0.22, YES)];  // Its soft light inward, brightening and dimming.
        [glow addSublayer:DPFlow(color, 2.5, 1, NO)];
        DPSet(text, &DPGlowKey, glow);
    }
    if (glow.superlayer != bar.layer) [bar.layer addSublayer:glow];
    DPFitGlow(glow, bar.layer);
    glow.opacity = 1;
}

void DPRefreshGlow(NSTextView *text) {
    CALayer *glow = DPGet(text, &DPGlowKey);
    NSView *bar = DPRoundedBar(text);
    if (glow && bar.layer) DPFitGlow(glow, bar.layer);
}
