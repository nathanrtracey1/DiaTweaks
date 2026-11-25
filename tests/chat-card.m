#import "Patches/EdgeToEdge/ChatCard.m"

char DPAnimationKey;
DPPatch DPEdgeToEdge, DPSquareChatCorners;
const CGFloat DPWindowPadding = 6;

static int failures;

static void expect(BOOL ok, NSString *what) {
    if (ok) return;
    failures++;
    printf("FAIL: %s\n", what.UTF8String);
}

static NSView *roundedView(NSRect frame, CGFloat radius, BOOL masks) {
    NSView *view = [[NSView alloc] initWithFrame:frame];
    view.wantsLayer = YES;
    view.layer.cornerRadius = radius;
    view.layer.masksToBounds = masks;
    return view;
}

static NSView *buildContainer(NSSize size, NSRect hostFrame, BOOL hostHidden, BOOL rootHidden, BOOL cardHidden, CGFloat cardRadius, BOOL cardMasks, BOOL directHost, NSView **outCard) {
    NSView *container = [[NSView alloc] initWithFrame:(NSRect){NSZeroPoint, size}];
    NSView *content = roundedView((NSRect){NSZeroPoint, size}, 10, YES);
    NSView *root = [[NSView alloc] initWithFrame:(NSRect){NSZeroPoint, size}];
    root.hidden = rootHidden;
    NSView *webHost = roundedView(NSMakeRect(0, 0, size.width - NSWidth(hostFrame), size.height), 10, YES);
    [root addSubview:webHost];
    NSView *host = directHost ? roundedView(hostFrame, cardRadius, cardMasks) : [[NSView alloc] initWithFrame:hostFrame];
    host.hidden = hostHidden;
    NSView *card = host;
    if (!directHost) {
        card = roundedView((NSRect){NSZeroPoint, hostFrame.size}, cardRadius, cardMasks);
        card.hidden = cardHidden;
        [host addSubview:card];
    }
    [root addSubview:host];
    [content addSubview:root];
    [container addSubview:content];
    if (outCard) *outCard = card;
    return container;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSView *card = nil;

        NSView *standard = buildContainer(NSMakeSize(800, 520), NSMakeRect(460, 0, 334, 512), NO, NO, NO, 10, YES, NO, &card);
        expect(DPChatCard(standard) == card, @"standard 800pt window detects 334pt chat card");

        NSView *wide1440 = buildContainer(NSMakeSize(1440, 900), NSMakeRect(1114, 0, 320, 892), NO, NO, NO, 10, YES, NO, &card);
        expect(DPChatCard(wide1440) == card, @"1440pt window detects Dia minimum 320pt chat card");

        NSView *wide2560 = buildContainer(NSMakeSize(2560, 1400), NSMakeRect(2234, 0, 320, 1392), NO, NO, NO, 10, YES, NO, &card);
        expect(DPChatCard(wide2560) == card, @"2560pt window detects Dia minimum 320pt chat card");

        for (CGFloat w = 1100; w <= 1500; w += 50) {
            NSView *resized = buildContainer(NSMakeSize(w, 900), NSMakeRect(w - 326, 0, 320, 892), NO, NO, NO, 10, YES, NO, &card);
            expect(DPChatCard(resized) == card, [NSString stringWithFormat:@"no snap across width/4 at %.0fpt", w]);
        }

        NSView *narrow = buildContainer(NSMakeSize(640, 500), NSMakeRect(434, 0, 200, 492), NO, NO, NO, 10, YES, NO, &card);
        expect(DPChatCard(narrow) == card, @"narrow 640pt window still scales threshold to width/4");

        NSView *direct = buildContainer(NSMakeSize(1440, 900), NSMakeRect(1114, 0, 320, 892), NO, NO, NO, 10, YES, YES, &card);
        expect(DPChatCard(direct) == card, @"direct rounded host view matches as chat card");

        NSView *hiddenHost = buildContainer(NSMakeSize(1440, 900), NSMakeRect(1440, 8, 360, 892), YES, NO, NO, 10, YES, NO, &card);
        expect(DPChatCard(hiddenHost) == nil, @"hidden assistantPanelContainerView does not match");

        NSView *hiddenCard = buildContainer(NSMakeSize(1440, 900), NSMakeRect(1114, 0, 320, 892), NO, NO, YES, 10, YES, NO, &card);
        expect(DPChatCard(hiddenCard) == nil, @"hidden chat card subview does not match");

        NSView *hiddenRoot = buildContainer(NSMakeSize(1440, 900), NSMakeRect(1114, 0, 320, 892), NO, YES, NO, 10, YES, NO, &card);
        expect(DPChatCard(hiddenRoot) == nil, @"hidden tab root does not match");

        NSView *tooNarrowWide = buildContainer(NSMakeSize(1440, 900), NSMakeRect(1190, 0, 240, 892), NO, NO, NO, 10, YES, NO, &card);
        expect(DPChatCard(tooNarrowWide) == nil, @"240pt rounded view on wide window is ignored");

        NSView *tooNarrowSmall = buildContainer(NSMakeSize(640, 500), NSMakeRect(470, 0, 160, 492), NO, NO, NO, 10, YES, NO, &card);
        expect(DPChatCard(tooNarrowSmall) == nil, @"width/4 rounded view on narrow window is ignored");

        NSView *tooShort = buildContainer(NSMakeSize(1440, 900), NSMakeRect(1114, 0, 320, 400), NO, NO, NO, 10, YES, NO, &card);
        expect(DPChatCard(tooShort) == nil, @"short rounded view <= height/2 is ignored");

        NSView *unmasked = buildContainer(NSMakeSize(1440, 900), NSMakeRect(1114, 0, 320, 892), NO, NO, NO, 10, NO, NO, &card);
        expect(DPChatCard(unmasked) == nil, @"unmasked view is ignored");

        NSView *originZero = buildContainer(NSMakeSize(1440, 900), NSMakeRect(0, 0, 320, 892), NO, NO, NO, 10, YES, NO, &card);
        expect(DPChatCard(originZero) == nil, @"host at origin (0,0) is skipped as webpage");
    }
    if (failures) return 1;
    puts("PASS: chat card detection handles wide windows and hidden panels");
    return 0;
}
