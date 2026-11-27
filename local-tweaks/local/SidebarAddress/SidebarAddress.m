#import "SidebarAddress.h"

static const CGFloat DPPillHeight = 30, DPPillInset = 6, DPPillGap = 6, DPNavigationSpace = 4;
static NSHashTable<NSView *> *DPSidebarRoots;
static char DPContentFrameKey;

CGFloat DPSidebarAddressProgress(void) { return DPSidebarAddress.progress * DPHideToolbar.progress; }

static NSView *DPOurs(NSView *parent, BOOL (*is)(NSView *)) {
    for (NSView *sub in parent.subviews) if (is(sub)) return sub;
    return nil;
}

static NSRect DPLaidOutContent(NSView *view) {
    return [DPDiaValue(view, &DPContentFrameKey, @(view.frame)) rectValue];
}

// The tab list: the full-width view Dia puts straight under the header.
static NSView *DPSidebarContent(NSView *root, NSView *header) {
    for (NSView *sub in root.subviews) {
        NSRect laidOut = DPLaidOutContent(sub);
        BOOL theirs = sub != header && !DPIsSidebarPill(sub) && !DPIsKind(sub, DPDiaSidebarFooter);
        if (theirs && NSWidth(laidOut) == NSWidth(root.bounds) && fabs(NSMinY(laidOut) - NSMaxY(header.frame)) < 0.5) return sub;
    }
    return nil;
}

static void DPPlacePill(NSView *root) {
    NSView *header = DPSubview(root, DPDiaSidebarHeader), *content = header && root.isFlipped ? DPSidebarContent(root, header) : nil;
    if (!content) return;
    CGFloat progress = DPSidebarAddressProgress(), shift = round((DPPillHeight + DPPillGap) * progress);
    NSView *pill = DPOurs(root, DPIsSidebarPill);
    if (!pill && progress > 0) [root addSubview:pill = DPMakeSidebarPill()];
    pill.hidden = progress == 0;
    pill.alphaValue = progress;
    pill.frame = NSMakeRect(DPPillInset, NSMaxY(header.frame) + shift - DPPillHeight - DPPillGap, MAX(0, NSWidth(root.bounds) - 2 * DPPillInset), DPPillHeight);
    DPRefreshSidebarPill(pill);

    NSRect laidOut = DPLaidOutContent(content), frame = laidOut;
    frame.origin.y += shift;
    frame.size.height = MAX(0, NSHeight(laidOut) - shift);
    DPOverride(content, &DPContentFrameKey, @(laidOut), @(frame));
    if (!NSEqualRects(content.frame, frame) && DPMayAdjust(content)) content.frame = frame;
}

// Right of the profile button, where the header is empty. A sidebar too narrow for both goes without the buttons.
static void DPPlaceNavigation(NSView *header) {
    CGFloat progress = DPSidebarAddressProgress();
    NSView *navigation = DPOurs(header, DPIsSidebarNavigation), *row = DPSubview(header, "NSStackView");
    if (!row || (!navigation && progress == 0)) return;
    if (!navigation) [header addSubview:navigation = DPMakeSidebarNavigation()];
    CGFloat left = NSMinX(row.frame), right = NSMaxX(row.frame);
    for (NSView *item in row.subviews) {
        if (item.hidden) continue;
        // The profile button's wrapper fills the row, so measure what it holds.
        NSView *shown = item.subviews.count == 1 ? item.subviews.firstObject : item;
        NSRect frame = [header convertRect:shown.bounds fromView:shown];
        if (NSMidX(frame) > NSMidX(row.frame) && NSWidth(frame) < NSWidth(row.frame) / 2) right = MIN(right, NSMinX(frame) - DPNavigationSpace);
        else left = MAX(left, NSMaxX(frame) + DPNavigationSpace);
    }
    NSSize size = DPSidebarNavigationSize();
    navigation.hidden = progress == 0 || right - left < size.width;
    navigation.alphaValue = progress;
    navigation.frame = NSMakeRect(right - size.width, round(NSMidY(row.frame) - size.height / 2), size.width, size.height);
    DPRefreshSidebarNavigation(navigation);
}

static void DPSidebarAddress_viewDidLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPSidebarAddress_viewDidLayout, self);
    [DPSidebarRoots addObject:self.view];
    DPPlacePill(self.view);
}

static void DPSidebarAddressHeader_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarAddressHeader_layout, self);
    DPPlaceNavigation(self);
}

static void DPRelayoutSidebarAddress(void) {
    for (NSView *root in DPSidebarRoots) DPSubview(root, DPDiaSidebarHeader).needsLayout = YES;
    DPRelayoutViews(DPSidebarRoots);
}

// Dia tells nobody here when the page or its history changes, so the sidebar looks at the toolbar a few times a second.
static void DPInstallSidebarAddress(void) {
    DPSidebarRoots = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaSidebarController, @selector(viewDidLayout), (IMP)DPSidebarAddress_viewDidLayout);
    DPHook(DPDiaSidebarHeader, @selector(layout), (IMP)DPSidebarAddressHeader_layout);
    DPInstallSidebarCommandBar();
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *t) {
        if (DPSidebarAddressProgress() == 0) return;
        for (NSView *root in DPSidebarRoots.allObjects) {
            if (!root.window.visible) continue;
            DPRefreshSidebarPill(DPOurs(root, DPIsSidebarPill));
            DPRefreshSidebarNavigation(DPOurs(DPSubview(root, DPDiaSidebarHeader), DPIsSidebarNavigation));
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
}

static NSString *DPVerifySidebarAddress(DPPatch *patch) {
    BOOL on = patch->on && DPHideToolbar.on;
    for (NSView *header in DPFindViews(DPDiaSidebarHeader)) {
        NSView *root = header.superview, *pill = DPOurs(root, DPIsSidebarPill);
        if (header.hiddenOrHasHiddenAncestor || !root.isFlipped) continue;
        BOOL shown = pill && !pill.hidden && pill.alphaValue > 0.99;
        if (shown != on) return on ? @"no address in the sidebar" : @"address still shows in the sidebar";
        CGFloat edge = on ? NSMaxY(pill.frame) + DPPillGap : NSMaxY(header.frame);
        if (on && fabs(NSMinY(pill.frame) - NSMaxY(header.frame)) > 0.5) return @"address isn't under the sidebar's header";
        NSView *below = nil;
        for (NSView *sub in root.subviews)
            if (sub != header && sub != pill && !sub.hidden && NSWidth(sub.frame) == NSWidth(root.bounds) && fabs(NSMinY(sub.frame) - edge) < 0.5) below = sub;
        if (!below) return on ? @"tabs didn't move down to make room for the address" : @"tabs aren't back under the sidebar's header";
    }
    return nil;
}

DP_PATCH(DPSidebarAddress) {
    .key = @"sidebarAddress",
    .order = 47,
    .title = @"Show Address in Sidebar",
    .detail = @"Show the page’s address at the top of the sidebar, with back, forward and reload beside the window buttons. Click the address or press ⌘L to open Dia’s command bar over it.",
    .symbol = @"sidebar.squares.left",
    .tint = @"systemIndigoColor",
    .requires = @"hideToolbar",
    .installLate = YES,
    .section = @"Showing the Toolbar",
    .classes = DPClasses(DPDiaSidebarController, DPDiaSidebarHeader, DPDiaToolbar, DPDiaAddressField, DPDiaPopover, DPDiaCommandBar),
    .install = DPInstallSidebarAddress,
    .relayout = DPRelayoutSidebarAddress,
    .verify = DPVerifySidebarAddress,
};
