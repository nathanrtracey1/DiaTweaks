#import "Patches/EdgeToEdge/EdgeToEdge.h"
#import <objc/runtime.h>

#define DPDiaChatContentContainer "_TtC6WindowP33_609C411878B0DC104EFC1CB446BE621E36AssistantSidebarContentContainerView"

extern DPPatch DPEdgeToEdgeWithChat, DPSquareChatCorners;

typedef struct CACornerRadii { CGSize topLeft, topRight, bottomRight, bottomLeft; } CACornerRadii;

@interface CALayer (DPChatE2ECornerRadii)
@property CACornerRadii cornerRadii;
@end

static char DPChatHostRequestedFrameKey, DPChatAnimationKey;
static Class DPHookedChatHostClass;
static void (*DPNSViewSetFrame)(id, SEL, NSRect);

static void DPSetRawFrame(NSView *view, NSRect frame) {
    if (DPNSViewSetFrame) DPNSViewSetFrame(view, @selector(setFrame:), frame);
    else view.frame = frame;
}

static NSValue *DPChatHostRequestedFrame(NSView *host) {
    return DPGet(host, &DPChatHostRequestedFrameKey);
}

static void DPSetChatHostRequestedFrame(NSView *host, NSRect frame) {
    DPSet(host, &DPChatHostRequestedFrameKey, [NSValue valueWithRect:frame]);
}

static BOOL DPChatIsOpen(NSView *root, NSView *host) {
    if (host.hidden) return NO;
    for (NSView *v in root.subviews) {
        if (!v.isHidden && NSWidth(v.frame) > 0 && [NSStringFromClass(v.class) containsString:@"AssistantSidebarDraggerHandleView"])
            return YES;
    }
    NSValue *requested = DPChatHostRequestedFrame(host);
    if (requested) {
        NSRect r = requested.rectValue;
        if (NSMinX(r) >= 2 || NSMinY(r) >= 2) return YES;
    }
    return NSMinX(host.frame) >= 2 || NSMinY(host.frame) >= 2;
}

static BOOL DPIsChatCard(NSView *v, NSSize size) {
    return !v.hidden && v.layer.masksToBounds && v.layer.cornerRadius > 0
        && NSWidth(v.bounds) > MIN(size.width / 4, 240) && NSHeight(v.bounds) > size.height / 2;
}

static NSRect DPEdgeToEdgeChatFrame(NSView *host, NSRect frame) {
    CGFloat inset = DPEdgeToEdge.progress * DPWindowPadding;
    if (inset == 0) return frame;
    if (fabs(frame.origin.y - DPWindowPadding) < 1.0) {
        frame.origin.y -= inset;
        frame.size.height += inset * 2;
    }
    if (fabs(frame.origin.x - DPWindowPadding) < 1.0) {
        frame.origin.x -= inset;
        if (DPSquareChatCorners.on) frame.size.width += inset;
    }
    return frame;
}

static void DPChatHost_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    NSAnimationContext *context = NSAnimationContext.currentContext;
    if (context.allowsImplicitAnimation || CATransaction.animationDuration > 0) {
        CFTimeInterval duration = context.duration ?: CATransaction.animationDuration;
        CAMediaTimingFunction *timing = context.timingFunction ?: [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
        DPSet(self, &DPChatAnimationKey, @[ @(CACurrentMediaTime() + duration), timing ]);
    }
    DPSetChatHostRequestedFrame(self, frame);
    NSRect adjusted = (DPEdgeToEdgeWithChat.on && DPEdgeToEdge.on && DPMayAdjust(self))
        ? DPEdgeToEdgeChatFrame(self, frame) : frame;
    DPCallOriginal(DPChatHost_setFrame, self, adjusted);
}

static NSView *DPChatCardHost(NSView *container) {
    NSView *content = DPRoundedContent(container);
    if (!content) return nil;
    NSSize size = content.bounds.size;
    for (NSView *root in content.subviews) {
        if (root.hidden) continue;
        for (NSView *host in root.subviews) {
            if (!DPChatIsOpen(root, host)) continue;
            if (DPIsChatCard(host, size) || DPFindView(host, ^BOOL(NSView *v) { return DPIsChatCard(v, size); }) != nil) {
                if (host.class != DPHookedChatHostClass && [NSStringFromClass(host.class) containsString:@"AssistantSidebarContentContainerView"]) {
                    DPHookedChatHostClass = host.class;
                    DPHookClass(host.class, @selector(setFrame:), (IMP)DPChatHost_setFrame);
                }
                return host;
            }
        }
    }
    return nil;
}

static NSEdgeInsets DPGaps(NSView *superview, NSRect frame) {
    NSRect bounds = superview.bounds;
    CGFloat low = NSMinY(frame) - NSMinY(bounds), high = NSMaxY(bounds) - NSMaxY(frame);
    return NSEdgeInsetsMake(superview.isFlipped ? low : high, NSMinX(frame) - NSMinX(bounds), superview.isFlipped ? high : low, NSMaxX(bounds) - NSMaxX(frame));
}

static BOOL DPIsPadding(CGFloat gap) { return fabs(gap - DPWindowPadding) < 0.5; }

static NSRect DPChatE2E_ExpandedFrame(NSView *view, NSRect frame, CGFloat amount) {
    CGFloat inset = amount * DPWindowPadding;
    NSView *superview = view.superview;
    if (inset == 0 || !superview) return frame;
    NSEdgeInsets gaps = DPGaps(superview, frame);
    if (DPIsPadding(gaps.left)) frame.origin.x -= inset, frame.size.width += inset;
    if (DPIsPadding(gaps.right)) frame.size.width += inset;
    if (DPIsPadding(gaps.top)) {
        frame.size.height += inset;
        if (superview.isFlipped) frame.origin.y -= inset;
    }
    if (DPIsPadding(gaps.bottom)) {
        frame.size.height += inset;
        if (!superview.isFlipped) frame.origin.y -= inset;
    }
    return frame;
}

static void DPApplyMask(NSView *container, CALayer *layer, CGFloat left, CGFloat right) {
    if ([layer respondsToSelector:@selector(setCornerRadii:)]) {
        layer.mask = nil;
        layer.maskedCorners = DPLeftCorners | DPRightCorners;
        CGFloat l = MAX(0.01, layer.cornerRadius * (1 - left));
        CGFloat r = MAX(0.01, layer.cornerRadius * (1 - right));
        CACornerRadii radii = { { l, l }, { r, r }, { r, r }, { l, l } };
        DPAnimateLayer(container, layer, @"cornerRadii", [NSValue valueWithBytes:&radii objCType:@encode(CACornerRadii)]);
        return;
    }
    layer.mask = nil;
    layer.maskedCorners = (left >= 0.5 ? 0 : DPLeftCorners) | (right >= 0.5 ? 0 : DPRightCorners);
}

static void DPChatE2E_ApplySquareCorners(NSView *container) {
    NSView *card = DPChatCard(container);
    if (!card) return;
    CGFloat amount = DPEdgeToEdgeAmount(container);
    BOOL beside = NSMinX(container.frame) > DPWindowPadding + 1;
    CGFloat left = (beside ? DPSquareSidebarCorners.progress : 1.0) * amount;
    CGFloat right = DPSquareChatCorners.progress * amount;
    DPWithoutAnimation(^{
        CALayer *cardLayer = card.layer;
        if (cardLayer) {
            if (cardLayer.cornerCurve != kCACornerCurveContinuous) cardLayer.cornerCurve = kCACornerCurveContinuous;
            DPApplyMask(DPChatCardHost(container) ?: container, cardLayer, left, right);
        }
        CALayer *containerLayer = DPRoundedContent(container).layer;
        if (containerLayer && containerLayer != cardLayer) {
            if (containerLayer.cornerCurve != kCACornerCurveContinuous) containerLayer.cornerCurve = kCACornerCurveContinuous;
            DPApplyMask(container, containerLayer, left, 1.0);
        }
    });
}

static void DPChatE2E_Restyle(NSView *container) {
    if (!DPChatCard(container)) return;
    NSView *host = DPChatCardHost(container);
    if (!DPEdgeToEdgeWithChat.on || !DPEdgeToEdge.on) {
        if (host) {
            NSValue *hostReq = DPChatHostRequestedFrame(host);
            if (hostReq && !NSEqualRects(host.frame, hostReq.rectValue) && DPMayAdjust(host)) {
                host.frame = hostReq.rectValue;
                host.needsLayout = host.needsDisplay = YES;
            }
        }
        return;
    }
    CGFloat amount = DPEdgeToEdgeAmount(container);
    NSValue *requested = DPRequestedFrame(container);
    if (requested && amount > 0) {
        NSRect expanded = DPChatE2E_ExpandedFrame(container, requested.rectValue, amount);
        if (!NSEqualRects(container.frame, expanded) && DPMayAdjust(container))
            DPSetRawFrame(container, expanded);
    }
    if (host) {
        NSValue *hostReq = DPChatHostRequestedFrame(host);
        if (!hostReq) {
            DPSetChatHostRequestedFrame(host, host.frame);
            hostReq = [NSValue valueWithRect:host.frame];
        }
        NSRect target = DPEdgeToEdgeChatFrame(host, hostReq.rectValue);
        if (!NSEqualRects(host.frame, target) && DPMayAdjust(host)) {
            host.frame = target;
            host.needsLayout = host.needsDisplay = YES;
        }
    }
    DPChatE2E_ApplySquareCorners(container);
}

static void DPChatE2E_Relayout(void) {
    DPRelayoutContainers();
    for (NSView *container in DPContainers.allObjects) DPChatE2E_Restyle(container);
}

static void DPChatE2E_containerSetFrame(NSView *self, SEL _cmd, NSRect frame) {
    DPCallOriginal(DPChatE2E_containerSetFrame, self, frame);
    if (!DPEdgeToEdgeWithChat.on || !DPEdgeToEdge.on) return;
    if (!DPChatCard(self)) return;
    CGFloat amount = DPMayAdjust(self) ? DPEdgeToEdgeAmount(self) : 0;
    if (amount <= 0) return;
    NSRect expanded = DPChatE2E_ExpandedFrame(self, frame, amount);
    if (!NSEqualRects(self.frame, expanded)) DPSetRawFrame(self, expanded);
}

static void DPChatE2E_layoutOrUpdateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPChatE2E_layoutOrUpdateLayer, self);
    DPChatE2E_Restyle(self);
}

static void DPInstallEdgeToEdgeWithChat(void) {
    DPNSViewSetFrame = (void (*)(id, SEL, NSRect))[NSView instanceMethodForSelector:@selector(setFrame:)];
    DPHook(DPDiaContentContainer, @selector(setFrame:), (IMP)DPChatE2E_containerSetFrame);
    DPHook(DPDiaContentContainer, @selector(layout), (IMP)DPChatE2E_layoutOrUpdateLayer);
    DPHook(DPDiaContentContainer, @selector(updateLayer), (IMP)DPChatE2E_layoutOrUpdateLayer);
    DPHook(DPDiaChatContentContainer, @selector(setFrame:), (IMP)DPChatHost_setFrame);
}

DP_PATCH(DPEdgeToEdgeWithChat) {
    .key = @"edgeToEdgeWithChat",
    .defaultOn = YES,
    .order = 16,
    .title = @"Edge-to-Edge with Chat Open",
    .detail = @"Keep edge-to-edge web pages and docked Chat active when the Chat panel is open.",
    .symbol = @"sidebar.right",
    .tint = @"systemBlueColor",
    .section = @"Page",
    .requires = @"edgeToEdge",
    .installLate = YES,
    .classes = DPClasses(DPDiaContentContainer, DPDiaShadowView),
    .install = DPInstallEdgeToEdgeWithChat,
    .relayout = DPChatE2E_Relayout,
};

DP_PATCH(DPSquareChatCorners) {
    .key = @"squareChatCorners",
    .defaultOn = NO,
    .order = 21,
    .title = @"Square Corners Next to Chat",
    .detail = @"Give web pages square corners where they meet the Chat panel.",
    .symbol = @"sidebar.right",
    .tint = @"systemBlueColor",
    .section = @"Page",
    .requires = @"edgeToEdgeWithChat",
    .relayout = DPChatE2E_Relayout,
};
