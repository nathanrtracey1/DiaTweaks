#import "EdgeToEdge.h"

static char DPChatHostRequestedFrameKey;
static Class DPHookedChatHostClass;

NSValue *DPChatHostRequestedFrame(NSView *host) {
    return DPGet(host, &DPChatHostRequestedFrameKey);
}

void DPSetChatHostRequestedFrame(NSView *host, NSRect frame) {
    DPSet(host, &DPChatHostRequestedFrameKey, [NSValue valueWithRect:frame]);
}

NSView *DPRoundedContent(NSView *container) {
    return DPFindView(container, ^BOOL(NSView *v) { return v != container && v.layer.masksToBounds && v.layer.cornerRadius > 0; });
}

static BOOL DPChatIsOpen(NSView *root, NSView *host) {
    for (NSView *v in root.subviews) {
        if (!v.isHidden && NSWidth(v.frame) > 0 && [NSStringFromClass(v.class) containsString:@"AssistantSidebarDraggerHandleView"])
            return YES;
    }
    NSValue *requested = DPChatHostRequestedFrame(host);
    if (requested) {
        NSRect r = requested.rectValue;
        if (NSMinX(r) >= 2 || NSMinY(r) >= 2) return YES;
    }
    return (NSMinX(host.frame) >= 2 || NSMinY(host.frame) >= 2);
}

NSView *DPChatCardHost(NSView *container) {
    NSView *content = DPRoundedContent(container);
    NSSize size = content.bounds.size;
    BOOL (^isCard)(NSView *) = ^BOOL(NSView *v) {
        return v.layer.masksToBounds && v.layer.cornerRadius > 0 && NSWidth(v.bounds) > size.width / 4 && NSHeight(v.bounds) > size.height / 2;
    };
    for (NSView *root in content.subviews)
        for (NSView *host in root.subviews) {
            if (!DPChatIsOpen(root, host)) continue;
            if (isCard(host) || DPFindView(host, isCard) != nil) {
                if (host.class != DPHookedChatHostClass) {
                    DPHookedChatHostClass = host.class;
                    DPHookClass(host.class, @selector(setFrame:), (IMP)DPChatHost_setFrame);
                }
                return host;
            }
        }
    return nil;
}

NSView *DPChatCard(NSView *container) {
    NSView *content = DPRoundedContent(container);
    NSSize size = content.bounds.size;
    BOOL (^isCard)(NSView *) = ^BOOL(NSView *v) {
        return v.layer.masksToBounds && v.layer.cornerRadius > 0 && NSWidth(v.bounds) > size.width / 4 && NSHeight(v.bounds) > size.height / 2;
    };
    for (NSView *root in content.subviews)
        for (NSView *host in root.subviews) {
            if (!DPChatIsOpen(root, host)) continue;
            if (isCard(host)) return host;
            for (NSView *card in host.subviews) if (isCard(card)) return card;
        }
    return nil;
}

NSRect DPEdgeToEdgeChatFrame(NSView *host, NSRect frame) {
    CGFloat inset = DPEdgeToEdge.progress * DPWindowPadding;
    if (inset == 0) return frame;
    if (fabs(frame.origin.y - DPWindowPadding) < 1.0) {
        frame.origin.y -= inset;
        frame.size.height += inset * 2;
    }
    if (fabs(frame.origin.x - DPWindowPadding) < 1.0) {
        frame.origin.x -= inset;
        if (DPSquareChatCorners.on) {
            frame.size.width += inset;
        }
    }
    return frame;
}

void DPChatHost_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    NSAnimationContext *context = NSAnimationContext.currentContext;
    if (context.allowsImplicitAnimation || CATransaction.animationDuration > 0) {
        CFTimeInterval duration = context.duration ?: CATransaction.animationDuration;
        CAMediaTimingFunction *timing = context.timingFunction ?: [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
        DPSet(self, &DPAnimationKey, @[ @(CACurrentMediaTime() + duration), timing ]);
    }
    DPSetChatHostRequestedFrame(self, frame);
    NSRect adjusted = (DPEdgeToEdge.on && DPMayAdjust(self)) ? DPEdgeToEdgeChatFrame(self, frame) : frame;
    DPCallOriginal(DPChatHost_setFrame, self, adjusted);
}
