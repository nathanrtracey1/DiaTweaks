#import "StdPatch/StdPatch.h"

extern DPPatch DPEdgeToEdge, DPSquareSidebarCorners, DPSquareChatCorners;
extern const CGFloat DPWindowPadding;
extern char DPAnimationKey;
extern NSHashTable<NSView *> *DPContainers;
static const CACornerMask DPLeftCorners = kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner;
static const CACornerMask DPRightCorners = kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner;

NSValue *DPRequestedFrame(NSView *container);
NSView *DPRoundedContent(NSView *container);
NSView *DPChatCard(NSView *container);
NSView *DPChatCardHost(NSView *container);
NSRect DPEdgeToEdgeChatFrame(NSView *host, NSRect frame);
NSValue *DPChatHostRequestedFrame(NSView *host);
void DPSetChatHostRequestedFrame(NSView *host, NSRect frame);
void DPChatHost_setFrame(NSView *self, SEL _cmd, NSRect frame);
CGFloat DPBaseCornerRadius(NSView *container);
void DPAnimateLayer(NSView *container, CALayer *layer, NSString *key, id value);
void DPInstallRestyle(void);
void DPInstallPopover(void);
void DPRestyleContainer(NSView *container);
void DPApplySquareCorners(NSView *container);
void DPRoundCornerControls(NSView *container);
CGPathRef DPReshapeSetPath(CALayer *layer, BOOL shadow, CGPathRef path);
CAAnimation *DPReshapeDiaAnimation(CALayer *layer, CAAnimation *animation);
BOOL DPBesideSidebar(NSView *container);
BOOL DPCornersRound(CALayer *layer, BOOL right);
BOOL DPFullScreen(NSView *container);
CGFloat DPWindowCornerGrowth(NSWindow *window);
CGPathRef DPReshapeCorners(CGPathRef path, CGFloat extent, CGFloat rightScale, CGFloat leftScale);
