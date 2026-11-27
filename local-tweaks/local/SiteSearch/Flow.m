#import "SiteSearch.h"

static CAGradientLayer *DPFlowLayer(NSArray<NSColor *> *colors, CGFloat seconds) {
    CAGradientLayer *flow = [CAGradientLayer layer];
    flow.type = kCAGradientLayerConic;
    flow.startPoint = CGPointMake(0.5, 0.5);
    flow.endPoint = CGPointMake(0.5, 0);
    NSMutableArray *cg = [NSMutableArray new];
    for (NSColor *color in colors) [cg addObject:(id)color.CGColor];
    flow.colors = cg;
    if (!NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        CABasicAnimation *turn = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        turn.fromValue = @0;
        turn.toValue = @(-2 * M_PI * (seconds > 0 ? 1 : -1));  // Positive seconds turn clockwise: the y axis points up.
        turn.duration = fabs(seconds);
        turn.repeatCount = HUGE_VALF;
        [flow addAnimation:turn forKey:@"DPTurn"];
    }
    return flow;
}

// Light flowing along the bar's edge: two conic gradients of the site's shades turning opposite ways at different
// speeds, the second screened over the first, so the colors meet and part like Siri's glow. They turn under a mask of
// the edge; square and as wide as the bar's diagonal, they cover the bar at any angle.
CALayer *DPFlow(NSColor *color, CGFloat lineWidth, float opacity, BOOL pulses) {
    CALayer *band = [CALayer layer];
    band.opacity = opacity;
    CAShapeLayer *edge = [CAShapeLayer layer];
    edge.fillColor = nil;
    edge.strokeColor = NSColor.blackColor.CGColor;
    edge.lineWidth = lineWidth;
    band.mask = edge;
    NSColor *warm = DPShade(color, 0.015, 1, 0), *cool = DPShade(color, -0.015, 0.9, 0), *light = DPShade(color, 0, 1, 0.5), *deep = DPShade(color, 0, 0.75, 0);
    [band addSublayer:DPFlowLayer(@[ color, warm, light, color, cool, deep, color ], 8)];
    NSColor *clear = [color colorWithAlphaComponent:0];
    CAGradientLayer *over = DPFlowLayer(@[ clear, [light colorWithAlphaComponent:0.85], clear, [warm colorWithAlphaComponent:0.7], clear,
                                           [cool colorWithAlphaComponent:0.7], clear ], -13);
    over.compositingFilter = @"screenBlendMode";
    [band addSublayer:over];
    // It brightens and dims rather than growing: a band that grew would cover more of the field and seem to squeeze it.
    if (pulses && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pulse.fromValue = @(opacity * 0.5);
        pulse.toValue = @(opacity * 1.4);
        pulse.duration = 2.6;
        pulse.autoreverses = YES;
        pulse.repeatCount = HUGE_VALF;
        pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [band addAnimation:pulse forKey:@"DPPulse"];
    }
    return band;
}

// The steady glow brightens and dims a little, out of step with the flow.
void DPBreathe(CALayer *layer) {
    if (NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) return;
    CABasicAnimation *breathe = [CABasicAnimation animationWithKeyPath:@"opacity"];
    breathe.fromValue = @0.55;
    breathe.toValue = @1;
    breathe.duration = 1.8;
    breathe.autoreverses = YES;
    breathe.repeatCount = HUGE_VALF;
    breathe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:breathe forKey:@"DPBreathe"];
}
