#import "Patches/Peek/Peek.h"
#import <Carbon/Carbon.h>

static const CGFloat DPPeekShadowRoom = 48;

static const CGFloat DPPeekEdgeAlpha = 0.12;

static NSRect DPPeekCardRect(NSRect area) { return NSInsetRect(area, NSWidth(area) * 0.09, MAX(10, NSHeight(area) * 0.012)); }

@implementation DPPeekCard

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

- (NSRect)cardFrame {
    NSRect card = DPPeekCardRect(self.bounds), page = self.bounds;
    CGFloat g = self.grown;
    NSRect frame = NSMakeRect(NSMinX(card) + (NSMinX(page) - NSMinX(card)) * g, NSMinY(card) + (NSMinY(page) - NSMinY(card)) * g,
                              NSWidth(card) + (NSWidth(page) - NSWidth(card)) * g, NSHeight(card) + (NSHeight(page) - NSHeight(card)) * g);
    // Pixel-aligned: fractional placement blurs Chromium's text.
    return [self backingAlignedRect:frame options:NSAlignAllEdgesNearest];
}

- (void)layout {
    [super layout];
    NSRect card = self.cardFrame;
    self.dim.frame = self.bounds;
    self.card.frame = NSInsetRect(card, -DPPeekShadowRoom, -DPPeekShadowRoom);
    self.clip.frame = self.shade.frame = NSInsetRect(self.card.bounds, DPPeekShadowRoom, DPPeekShadowRoom);
    self.clip.layer.borderColor = [NSColor colorWithWhite:1 alpha:DPPeekEdgeAlpha * (1 - self.grown)].CGColor;
    self.controls.frame = (NSRect){{NSMaxX(card) + 12, NSMinY(card) + 4}, self.controls.frame.size};
    // Not animated with the sidebar slide: the page redraws at its new size at once, so it must cover both card sizes meanwhile.
    CGFloat bar = DPPeekToolbarInset(self);
    NSSize page = NSMakeSize(NSWidth(self.clip.bounds), MAX(0, NSHeight(self.clip.bounds) - bar));
    if (self.paneMoves) page = NSMakeSize(MAX(page.width, NSWidth(self.host.frame)), MAX(page.height, NSHeight(self.host.frame)));
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0;
        context.allowsImplicitAnimation = NO;
        BOOL flipped = self.clip.isFlipped;
        self.host.frame = (NSRect){{0, flipped ? bar : NSHeight(self.clip.bounds) - bar - page.height}, page};
        DPPeekPlaceToolbar(self);
        DPPeekLayoutHints(self.controls, NSWidth(self.bounds) - NSMaxX(self.controls.frame) - 8);
    }];
}

- (void)followPane {
    NSView *pane = self.pane, *root = self.superview;
    if (!pane.window || !root) return;
    NSRect frame = [root convertRect:pane.bounds fromView:pane];
    if (NSEqualRects(frame, self.frame)) return;
    NSAnimationContext *dia = NSAnimationContext.currentContext;
    if (!dia.timingFunction) return (void)(self.frame = frame);
    self.paneMoves++;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = dia.duration;
        context.timingFunction = dia.timingFunction;
        context.allowsImplicitAnimation = YES;
        self.animator.frame = frame;
        [self layoutSubtreeIfNeeded];
    } completionHandler:^{
        if (!--self.paneMoves) self.needsLayout = YES;
    }];
}

- (void)mouseDown:(NSEvent *)event { [self close:DPPeekClose]; }
- (void)rightMouseDown:(NSEvent *)event {}
- (void)scrollWheel:(NSEvent *)event {}
- (void)control:(NSButton *)sender { [self close:sender.tag]; }

- (BOOL)stopWatching {
    if (self.closing) return NO;
    self.closing = YES;
    if (self.monitor) [NSEvent removeMonitor:self.monitor];
    if (self.paneObserver) [NSNotificationCenter.defaultCenter removeObserver:self.paneObserver];
    self.monitor = self.paneObserver = nil;
    self.controls.alphaValue = 0;
    DPPeekHideTabBadge(self);
    DPPeekHideFind(self);
    return YES;
}

- (void)close:(DPPeekExit)exit {
    if (![self stopWatching]) return;
    if (exit == DPPeekClose) [self animateOut:^{ [self finish:exit]; }];
    else if (exit == DPPeekTab) [self animateExpand:^{ [self finish:exit]; }];
    else [self finish:exit];
}

- (void)handOver {
    NSWindow *window = self.window;
    [self stopWatching];
    [self removeFromSuperview];
    [window resetCursorRects];
    // The card must be off screen before the page detaches, or it flashes blank.
    if (self.grown < 1) [CATransaction flush];
    [self.page detachFromPaneHostView:self.host];
}

@end

DPPeekCard *DPPeekCardIn(NSWindow *window) {
    return (DPPeekCard *)DPFindView(window.contentView, ^BOOL(NSView *view) {
        return [view isKindOfClass:DPPeekCard.class] && !((DPPeekCard *)view).closing;
    });
}

static NSView *DPPeekPane(NSWindow *window, NSRect area) {
    NSView *pane = nil, *under = nil;
    CGFloat overlap = 0;
    for (NSView *candidate in DPFindViews(DPDiaContentPane)) {
        if (candidate.window != window) continue;
        NSRect hit = NSIntersectionRect([window convertRectToScreen:[candidate convertRect:candidate.bounds toView:nil]], area);
        if (!candidate.isHiddenOrHasHiddenAncestor && NSWidth(hit) * NSHeight(hit) > overlap) {
            under = candidate;
            overlap = NSWidth(hit) * NSHeight(hit);
        }
        if (NSWidth(candidate.bounds) * NSHeight(candidate.bounds) > NSWidth(pane.bounds) * NSHeight(pane.bounds)) pane = candidate;
    }
    return under ?: pane;
}

static NSView *DPPeekHolder(NSWindow *window, NSView *pane) {
    for (NSView *view = pane; view && view != window.contentView; view = view.superview)
        if (view.layer.cornerRadius > 0 && view.layer.masksToBounds) return view;
    return window.contentView;
}

@interface DPPeekBacking : NSView
@end

@implementation DPPeekBacking
- (BOOL)wantsUpdateLayer { return YES; }
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self updateLayer]; }

// Resolved in the card's own appearance: outside a draw pass the plain colour is the Light one, a white card in Dark Mode.
- (void)updateLayer {
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{ self.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor; }];
}
@end

static NSView *DPLayerView(Class kind) {
    NSView *view = [kind new];
    view.wantsLayer = YES;
    return view;
}

static BOOL DPIsDigitKey(NSEvent *event) {
    NSString *key = event.charactersIgnoringModifiers;
    return key.length == 1 && [key characterAtIndex:0] >= '1' && [key characterAtIndex:0] <= '9';
}

// Only the app and Window menus; the others act on the tab behind the card.
static BOOL DPPerformAppShortcut(NSEvent *event, NSEventModifierFlags mods) {
    if (!(mods & (NSEventModifierFlagCommand | NSEventModifierFlagControl))) return NO;
    return [NSApp.mainMenu.itemArray.firstObject.submenu performKeyEquivalent:event] || [NSApp.windowsMenu performKeyEquivalent:event];
}

// The page keeps every ⌘ and ⌃ shortcut instead of handing it to Dia, and Blink doesn't paste or undo on a key equivalent.
// So the edit commands go to the page. Dia's other commands would act on the tab behind the card.
static BOOL DPPeekPageShortcut(DPPeekCard *peek, NSEvent *event, NSEventModifierFlags mods, NSResponder *focus) {
    BOOL command = mods == NSEventModifierFlagCommand, shifted = mods == (NSEventModifierFlagCommand | NSEventModifierFlagShift);
    SEL edit = NULL;
    if (command && DPEventIsKey(event, @"x")) edit = @selector(cut:);
    else if (command && DPEventIsKey(event, @"c")) edit = @selector(copy:);
    else if (command && DPEventIsKey(event, @"v")) edit = @selector(paste:);
    else if (command && DPEventIsKey(event, @"a")) edit = @selector(selectAll:);
    else if (command && DPEventIsKey(event, @"z")) edit = @selector(undo:);
    else if (shifted && DPEventIsKey(event, @"z")) edit = @selector(redo:);
    else if (mods == (NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagShift) && DPEventIsKey(event, @"v")) edit = @selector(pasteAsPlainText:);
    return edit && [focus respondsToSelector:edit] && [NSApp sendAction:edit to:focus from:nil];
}

static NSMenuItem *DPPeekItemFor(NSMenu *menu, NSEvent *event) {
    for (NSMenuItem *item in menu.itemArray) {
        NSMenuItem *found = DPPeekIsShortcut(event, item) ? item : DPPeekItemFor(item.submenu, event);
        if (found) return found;
    }
    return nil;
}

// The new tab and window shortcuts, wherever the user has put them, act on the window and not on the tab behind the card.
static BOOL DPPeekWindowCommand(NSEvent *event) {
    if (!(event.modifierFlags & NSEventModifierFlagCommand)) return NO;
    return [@[ @"New Tab", @"New Window", @"New Incognito Window" ] containsObject:DPPeekItemFor(NSApp.mainMenu, event).title ?: @""];
}

// A focused Peek page swallows the shortcuts Dia's tabs pass on to the menu. ⌘S and every ⌃ shortcut, such as ⌃Tab and ⌃1–9, go on to it.
static id DPWatchKeys(DPPeekCard *card) {
    __weak DPPeekCard *weak = card;
    return [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        DPPeekCard *peek = weak;
        if (!peek || event.window != peek.window) return event;
        NSEventModifierFlags mods = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask & ~(NSEventModifierFlagCapsLock | NSEventModifierFlagNumericPad);
        // A page's field is not an NSText; Escape there must cancel an input method's composition, not close the card.
        id responder = peek.window.firstResponder;
        BOOL command = mods == NSEventModifierFlagCommand, control = mods == NSEventModifierFlagControl;
        BOOL editing = [responder isKindOfClass:NSText.class] || ([responder conformsToProtocol:@protocol(NSTextInputClient)] && [responder hasMarkedText]);
        BOOL onPage = [responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:peek.host];
        BOOL toMenu = (command && DPEventIsKey(event, @"s")) || (onPage ? (mods & NSEventModifierFlagControl) || DPPeekWindowCommand(event) : control && DPIsDigitKey(event));
        if (DPPeekCopyURL(peek, event) || DPPeekZoomShortcut(peek, event) || DPPeekFindShortcut(peek, event, mods)) return nil;
        if (onPage && DPPeekPageShortcut(peek, event, mods, responder)) return nil;
        if (command && DPEventIsKey(event, @"o")) [peek close:DPPeekTab];
        // Dia's menu would navigate the tab behind the card; without the toolbar these stay stock.
        else if (command && peek.toolbar && DPEventIsKey(event, @"[")) DPPeekNavigate(peek.page, DPPeekBack);
        else if (command && peek.toolbar && DPEventIsKey(event, @"]")) DPPeekNavigate(peek.page, DPPeekForward);
        else if (command && peek.toolbar && DPEventIsKey(event, @"r")) DPPeekNavigate(peek.page, DPPeekReload);
        else if (command && peek.toolbar && DPEventIsKey(event, @"l")) DPPeekEditToolbarAddress(peek);
        else if ((command && DPEventIsKey(event, @"w")) || (!mods && event.keyCode == kVK_Escape && !editing)) [peek close:DPPeekClose];
        else if (!DPPerformAppShortcut(event, mods) && !(toMenu && [NSApp.mainMenu performKeyEquivalent:event])) return event;
        return nil;
    }];
}

NSView *DPPeekWarmHost(NSWindow *window, id<DPPeekPage> page) {
    NSView *host = [page createPaneHostView], *pane = DPPeekPane(window, (NSRect){NSEvent.mouseLocation, {1, 1}});
    if (!host || !pane) return nil;
    NSView *holder = DPPeekHolder(window, pane);
    NSRect area = [holder convertRect:pane.bounds fromView:pane];
    host.frame = NSOffsetRect(DPPeekCardRect((NSRect){NSZeroPoint, area.size}), NSMinX(area), NSMinY(area));
    [holder addSubview:host positioned:NSWindowBelow relativeTo:nil];
    [page attachToPaneHostView:host];
    return host;
}

DPPeekCard *DPPeekShowCard(NSWindow *window, id<DPPeekPage> page, NSView *warmHost, NSRect screenLink) {
    NSView *host = warmHost ?: [page createPaneHostView], *pane = DPPeekPane(window, screenLink);
    if (!window || !host || DPPeekCardIn(window)) return nil;
    NSView *holder = DPPeekHolder(window, pane);
    DPPeekCard *peek = [[DPPeekCard alloc] initWithFrame:pane ? [holder convertRect:pane.bounds fromView:pane] : holder.bounds];
    peek.autoresizingMask = pane ? NSViewNotSizable : NSViewWidthSizable | NSViewHeightSizable;
    peek.pane = pane;
    peek.page = page;
    peek.host = host;
    peek.dim = DPLayerView(NSView.class);
    peek.dim.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:DPPeekDarkness()].CGColor;
    peek.card = DPLayerView(NSView.class);
    NSShadow *shadow = [NSShadow new];
    shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.35];
    shadow.shadowBlurRadius = 24;
    shadow.shadowOffset = NSMakeSize(0, -6);
    peek.shade = DPLayerView(DPPeekBacking.class);
    peek.shade.shadow = shadow;
    peek.clip = DPLayerView(DPPeekBacking.class);
    peek.clip.layer.masksToBounds = YES;
    for (NSView *view in @[peek.shade, peek.clip]) {
        view.layer.cornerRadius = 10;
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    peek.clip.layer.borderWidth = 1 / (window.backingScaleFactor ?: 2);
    peek.controls = DPPeekControls(peek, @selector(control:));
    [peek.clip addSubview:host];
    if (DPPeekShowsToolbar()) DPPeekAddToolbar(peek);
    [peek.card addSubview:peek.shade];
    [peek.card addSubview:peek.clip];
    for (NSView *view in @[peek.dim, peek.card, peek.controls]) [peek addSubview:view];
    [holder addSubview:peek positioned:NSWindowAbove relativeTo:nil];
    [peek layoutSubtreeIfNeeded];
    if (!warmHost) [page attachToPaneHostView:host];
    [window resetCursorRects];
    [window makeFirstResponder:host];
    if (pane) {
        pane.postsFrameChangedNotifications = YES;
        __weak DPPeekCard *weak = peek;
        peek.paneObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSViewFrameDidChangeNotification object:pane queue:nil
                                                                        usingBlock:^(NSNotification *note) { [weak followPane]; }];
    }
    peek.monitor = DPWatchKeys(peek);
    peek.link = [peek convertRect:[window convertRectFromScreen:screenLink] fromView:nil];
    [peek animateIn];
    return peek;
}
