#import "EdgeToEdge.h"

static char DPPathKey, DPShadowPathKey, DPPastPathsKey;
static NSMapTable<CALayer *, NSView *> *DPPathOwners;

// Private; fields in on-screen order from the top left.
typedef struct CACornerRadii { CGSize topLeft, topRight, bottomRight, bottomLeft; } CACornerRadii;

@interface CALayer (DPCornerRadii)
@property CACornerRadii cornerRadii;
@property(readonly) BOOL _usesCornerRadii;
@end

static void DPMaskCorners(NSView *container, CALayer *layer, CGFloat left, CGFloat right) {
    if ([layer respondsToSelector:@selector(setCornerRadii:)]) {
        layer.mask = nil;
        layer.maskedCorners = DPLeftCorners | DPRightCorners;
        // All zero, the radii stop counting and the layer clips to its cornerRadius again, so square stays a hair above zero.
        CGFloat l = MAX(0.01, layer.cornerRadius * (1 - left)), r = MAX(0.01, layer.cornerRadius * (1 - right));
        CACornerRadii radii = { { l, l }, { r, r }, { r, r }, { l, l } };
        DPAnimateLayer(container, layer, @"cornerRadii", [NSValue valueWithBytes:&radii objCType:@encode(CACornerRadii)]);
        return;
    }
    if ((left == 0 || left == 1) && (right == 0 || right == 1)) {
        layer.mask = nil;
        layer.maskedCorners = (left == 1 ? 0 : DPLeftCorners) | (right == 1 ? 0 : DPRightCorners);
        return;
    }
    CALayer *mask = layer.mask.sublayers.count == 2 ? layer.mask : [CALayer layer];
    if (mask != layer.mask) {
        for (int i = 0; i < 2; i++) {
            CALayer *half = [CALayer layer];
            half.backgroundColor = NSColor.blackColor.CGColor;
            half.cornerCurve = kCACornerCurveContinuous;
            half.maskedCorners = i ? DPRightCorners : DPLeftCorners;
            [mask addSublayer:half];
        }
    }
    CGRect bounds = layer.bounds;
    CGFloat half = CGRectGetWidth(bounds) / 2;
    mask.frame = bounds;
    mask.sublayers[0].frame = CGRectMake(0, 0, half + 1, CGRectGetHeight(bounds));
    mask.sublayers[1].frame = CGRectMake(half - 1, 0, half + 1, CGRectGetHeight(bounds));
    mask.sublayers[0].cornerRadius = layer.cornerRadius * (1 - left);
    mask.sublayers[1].cornerRadius = layer.cornerRadius * (1 - right);
    layer.mask = mask;
    layer.maskedCorners = 0;
}

static CGPathRef DPReshapePath(id owner, char *key, CGPathRef current, NSView *container, CGFloat base, CGFloat grow, CGFloat left, CGFloat right) {
    if (!current || CGRectGetWidth(CGPathGetBoundingBox(current)) < NSWidth(container.bounds) * 0.9) return NULL;
    id dia = DPDiaValue(owner, key, (__bridge id)current);
    if (dia == (__bridge id)current) dia = CFBridgingRelease(CGPathCreateCopy(current));
    CGPathRef path = DPReshapeCorners((__bridge CGPathRef)dia, base * 1.6, grow * (1 - right), grow * (1 - left));
    DPOverride(owner, key, dia, (__bridge id)path);
    if (!DPPathOwners) DPPathOwners = [NSMapTable weakToWeakObjectsMapTable];
    [DPPathOwners setObject:container forKey:owner];
    // Dia's next animation may start from a path we set, so each maps back to Dia's.
    NSMapTable *past = DPGet(owner, &DPPastPathsKey) ?: [NSMapTable strongToStrongObjectsMapTable];
    if (past.count > 8) [past removeAllObjects];
    [past setObject:dia forKey:(__bridge id)path];
    DPSet(owner, &DPPastPathsKey, past);
    return CGPathEqualToPath(path, current) ? NULL : path;
}

static void DPSetPath(CALayer *layer, NSString *key, CGPathRef path) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [layer setValue:(__bridge id)path forKey:key];
    [CATransaction commit];
}

static void DPReshapePaths(NSView *container, CGFloat base, CGFloat grow, CGFloat left, CGFloat right) {
    for (NSView *sub in container.subviews)
        for (CALayer *sublayer in sub.layer.sublayers) {
            CAShapeLayer *shape = [sublayer isKindOfClass:CAShapeLayer.class] ? (CAShapeLayer *)sublayer
                                : [sublayer.mask isKindOfClass:CAShapeLayer.class] ? (CAShapeLayer *)sublayer.mask : nil;
            CGPathRef path = DPReshapePath(shape, &DPPathKey, shape.path, container, base, grow, left, right);
            if (path) DPSetPath(shape, @"path", path);
            CGPathRef shadow = DPReshapePath(sublayer, &DPShadowPathKey, sublayer.shadowPath, container, base, grow, left, right);
            if (shadow) DPSetPath(sublayer, @"shadowPath", shadow);
        }
}

BOOL DPCornersRound(CALayer *layer, BOOL right) {
    if ([layer respondsToSelector:@selector(cornerRadii)] && layer._usesCornerRadii)
        return (right ? layer.cornerRadii.topRight.width : layer.cornerRadii.topLeft.width) >= 0.5;
    if (layer.mask) return layer.mask.sublayers[right].cornerRadius > 0;
    return layer.cornerRadius > 0 && (layer.maskedCorners & (right ? DPRightCorners : DPLeftCorners));
}

BOOL DPBesideSidebar(NSView *container) {
    return NSMinX(container.frame) > DPWindowPadding + 1;
}

BOOL DPFullScreen(NSView *container) {
    return (container.window.styleMask & NSWindowStyleMaskFullScreen) != 0;
}

static NSView *DPParentContainer(NSView *view) {
    for (NSView *v = view; v; v = v.superview)
        if (DPIsKind(v, DPDiaContentContainer)) return v;
    return view;
}

static CALayer *DPCornerShape(NSView *container, CGFloat *base, CGFloat *grow, CGFloat *left, CGFloat *right) {
    if (DPIsKind(container, DPDiaChatContentContainer)) {
        NSView *card = DPRoundedContent(container);
        CALayer *layer = card.layer;
        if (!layer) return nil;
        NSView *parent = DPParentContainer(container);
        *right = DPSquareChatCorners.progress * DPEdgeToEdge.progress;
        *left = (DPBesideSidebar(parent) ? DPSquareSidebarCorners.progress : 1.0) * DPEdgeToEdge.progress;
        *base = layer.cornerRadius;
        *grow = 1;
        return layer;
    }
    NSView *card = DPChatCard(container);
    CALayer *layer = (card ?: DPRoundedContent(container)).layer;
    if (!layer) return nil;
    if (card) {
        *right = DPSquareChatCorners.progress * DPEdgeToEdge.progress;
        *left = (DPBesideSidebar(container) ? DPSquareSidebarCorners.progress : 1.0) * DPEdgeToEdge.progress;
        *base = layer.cornerRadius;
        *grow = 1;
        return layer;
    }
    *right = DPFullScreen(container) ? DPEdgeToEdge.progress : 0;
    BOOL beside = DPBesideSidebar(container);
    *left = beside ? DPSquareSidebarCorners.progress * DPEdgeToEdge.progress : *right;
    CGFloat growth = DPWindowCornerGrowth(container.window);
    if (growth > 0 && layer.cornerRadius > 0 && beside) *left = 1 - (1 - *left) * (layer.cornerRadius - growth) / layer.cornerRadius;
    *base = DPBaseCornerRadius(container) ?: layer.cornerRadius;
    *grow = *base > 0 ? layer.cornerRadius / *base : 1;
    return layer;
}

void DPRoundCornerControls(NSView *container) {
    NSView *content = DPRoundedContent(container);
    NSView *bar = DPFindView(content, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaToolbar); });
    if (!bar || ![content.layer respondsToSelector:@selector(cornerRadii)]) return;
    CACornerRadii page = content.layer.cornerRadii;
    CGFloat width = NSWidth(content.bounds);
    DPFindView(bar, ^BOOL(NSView *view) {
        CALayer *layer = view.layer;
        CGFloat dia = layer.cornerRadius;
        if (view == bar || dia <= 0 || view.isHiddenOrHasHiddenAncestor) return NO;
        NSRect rect = [view convertRect:view.bounds toView:content];
        CGFloat top = content.isFlipped ? NSMinY(rect) : NSHeight(content.bounds) - NSMaxY(rect), left = NSMinX(rect), right = width - NSMaxX(rect);
        CGFloat topLeft = top < 12 && left < 12 ? MAX(dia, page.topLeft.width - MAX(top, left)) : dia;
        CGFloat topRight = top < 12 && right < 12 ? MAX(dia, page.topRight.width - MAX(top, right)) : dia;
        if (topLeft == dia && topRight == dia && !layer._usesCornerRadii) return NO;
        CGSize l = CGSizeMake(topLeft, topLeft), r = CGSizeMake(topRight, topRight), d = CGSizeMake(dia, dia);
        CACornerRadii radii = layer.contentsAreFlipped ? (CACornerRadii){ d, d, r, l } : (CACornerRadii){ l, r, d, d };
        DPAnimateLayer(container, layer, @"cornerRadii", [NSValue valueWithBytes:&radii objCType:@encode(CACornerRadii)]);
        return NO;
    });
}

void DPApplySquareCorners(NSView *container) {
    CGFloat base, grow, left, right;
    CALayer *layer = DPCornerShape(container, &base, &grow, &left, &right);
    if (!layer) return;
    layer.cornerCurve = kCACornerCurveContinuous;
    NSView *card = DPChatCard(container);
    NSView *host = card ? DPChatCardHost(container) : nil;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    DPMaskCorners(host ?: container, layer, left, right);
    DPReshapePaths(host ?: container, base, grow, left, right);
    if (host) {
        CALayer *containerLayer = DPRoundedContent(container).layer;
        if (containerLayer && containerLayer != layer) {
            containerLayer.cornerCurve = kCACornerCurveContinuous;
            DPMaskCorners(container, containerLayer, left, 1.0);
            DPReshapePaths(container, base, grow, left, 1.0);
        }
    }
    [CATransaction commit];
    DPRoundCornerControls(host ?: container);
}

CGPathRef DPReshapeSetPath(CALayer *layer, BOOL shadow, CGPathRef path) {
    NSView *container = [DPPathOwners objectForKey:layer];
    if (!container || !path || [DPGet(layer, &DPPastPathsKey) objectForKey:(__bridge id)path]) return path;
    CGFloat base, grow, left, right;
    if (!DPCornerShape(container, &base, &grow, &left, &right)) return path;
    return DPReshapePath(layer, shadow ? &DPShadowPathKey : &DPPathKey, path, container, base, grow, left, right) ?: path;
}

CAAnimation *DPReshapeDiaAnimation(CALayer *layer, CAAnimation *animation) {
    CABasicAnimation *move = (CABasicAnimation *)animation;
    if (![move isKindOfClass:CABasicAnimation.class] || !([move.keyPath isEqual:@"path"] || [move.keyPath isEqual:@"shadowPath"])) return animation;
    NSView *container = [DPPathOwners objectForKey:layer];
    if (!container) return animation;
    CGFloat base, grow, left, right;
    if (!DPCornerShape(container, &base, &grow, &left, &right)) return animation;
    CABasicAnimation *reshaped = [move copy];
    NSMapTable *past = DPGet(layer, &DPPastPathsKey);
    for (NSString *end in @[ @"fromValue", @"toValue" ]) {
        id value = [move valueForKey:end];
        CGPathRef path = (__bridge CGPathRef)([past objectForKey:value] ?: value);
        if (path && CGRectGetWidth(CGPathGetBoundingBox(path)) >= NSWidth(container.bounds) * 0.9)
            [reshaped setValue:(__bridge id)DPReshapeCorners(path, base * 1.6, grow * (1 - right), grow * (1 - left)) forKey:end];
    }
    return reshaped;
}

static NSString *DPVerifySquareCorners(DPPatch *patch) {
    for (NSView *container in DPFindViews(DPDiaContentContainer)) {
        NSView *content = DPChatCard(container) ?: DPRoundedContent(container);
        CALayer *layer = content.layer;
        if (!layer) return @"no rounded web content found";
        if (!DPBesideSidebar(container)) continue;
        BOOL square = patch->on && DPEdgeToEdge.on;
        if (DPCornersRound(layer, NO) == square) return square ? @"corners by the sidebar are round" : @"corners by the sidebar are square";
    }
    return nil;
}

DP_PATCH(DPSquareSidebarCorners) {
    .key = @"squareSidebarCorners",
    .defaultOn = YES,
    .order = 20,
    .title = @"Square Corners Next to Sidebar",
    .detail = @"Give web pages square corners where they meet the sidebar.",
    .symbol = @"square.fill",
    .tint = @"systemBlueColor",
    .section = @"Page",
    .requires = @"edgeToEdge",
    .verify = DPVerifySquareCorners,
};

static NSString *DPVerifySquareChatCorners(DPPatch *patch) {
    for (NSView *container in DPFindViews(DPDiaContentContainer)) {
        NSView *card = DPChatCard(container);
        if (!card) continue;
        CALayer *layer = card.layer;
        if (!layer) continue;
        BOOL square = patch->on && DPEdgeToEdge.on;
        if (DPCornersRound(layer, YES) == square) return square ? @"corners by Chat are round" : @"corners by Chat are square";
    }
    return nil;
}

DP_PATCH(DPSquareChatCorners) {
    .key = @"squareChatCorners",
    .defaultOn = NO,
    .order = 21,
    .title = @"Square Corners Next to Chat",
    .detail = @"Give web pages square corners where they meet the Chat panel.",
    .symbol = @"sidebar.right",
    .tint = @"systemBlueColor",
    .section = @"Page",
    .requires = @"edgeToEdge",
    .verify = DPVerifySquareChatCorners,
};
