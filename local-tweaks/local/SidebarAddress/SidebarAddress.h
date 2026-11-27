#import "StdPatch/StdPatch.h"

extern DPPatch DPSidebarAddress, DPHideToolbar;

// How far the address has moved into the sidebar, 0 to 1. It needs the toolbar hidden, or the address would show twice.
CGFloat DPSidebarAddressProgress(void);

// Dia's own toolbar keeps running while hidden, so the sidebar shows what it shows and presses what it has.
NSView *DPToolbarFor(NSWindow *window);
NSString *DPToolbarAddress(NSView *toolbar);
NSView *DPToolbarControl(NSView *toolbar, NSString *label);
BOOL DPToolbarControlEnabled(NSView *control);
void DPPressToolbarControl(NSView *control);
void DPEditAddress(NSWindow *window);

void DPInstallSidebarCommandBar(void);
NSView *DPAnchoredPopover(NSView *view);  // The ⌘L popover a view is in, while it opens over the pill.
void DPInstallSidebarGo(void);

NSView *DPMakeSidebarPill(void);
BOOL DPIsSidebarPill(NSView *view);
void DPRefreshSidebarPill(NSView *pill);

NSView *DPMakeSidebarNavigation(void);
BOOL DPIsSidebarNavigation(NSView *view);
NSSize DPSidebarNavigationSize(void);
void DPRefreshSidebarNavigation(NSView *navigation);
