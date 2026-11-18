#import "StdPatch/StdPatch.h"

#define DPDiaOpenURLEvents "_TtC13OpenURLClient19OpenURLEventManager"
#define DPDiaPopupWindow   "_TtC5Popup19PlatformPopupWindow"
#define DPDiaPopupBar      "_TtC5Popup22PopupNavigationBarView"
#define DPDiaPopupTitle    "_TtC13NavigationBar21AssistantBarTitleView"

extern DPPatch DPLittleDia, DPLittleDiaTabLinks, DPLittleDiaFollowRules;

// For a plain click Dia would open in a new tab; YES when Little Dia takes it. Peek's link hooks ask this first.
BOOL DPLittleDiaTakesTabLink(id page, NSURL *url, BOOL leavesPinned);

void DPInstallLittleDiaExtension(void);
BOOL DPWriteLittleDiaExtension(BOOL on);
NSString *DPLittleDiaExtensionProblem(void);
BOOL DPSendToLittleDia(NSDictionary *request);
BOOL DPLittleDiaStarting(void);
BOOL DPLittleDiaReady(void);

NSSize DPLittleDiaSize(void);
NSArray<NSView *> *DPLittleDiaRows(void);

void DPInstallLittleDiaRoute(void);
void DPOpenLinkInLittleDia(NSURL *url);
#define DPTabLinkWidth 0.8  // Of the page area's width.
#define DPTabLinkEdge 12    // Points kept above and below.
void DPOpenTabLinkInLittleDia(NSURL *url, NSWindow *source);  // Falls back to a tab, so the link is never lost.
void DPOpenBlankLittleDia(void);

void DPInstallLittleDiaLinkMenu(void);
NSString *DPLittleDiaLinkMenuProblem(void);

void DPInstallLittleDiaNewWindow(void);
void DPRefreshLittleDiaNewWindow(void);
NSString *DPLittleDiaNewWindowProblem(void);

#define DPLittleDiaWait 3
void DPExpectLittleDiaWindow(NSRect frame, NSDictionary *noted, void (^missed)(void), void (^claimed)(NSWindow *window));
BOOL DPIsLittleDiaWindow(NSWindow *window);
id DPLittleDiaPage(NSWindow *window);  // nil until Chromium hands the page over.
void DPInstallLittleDiaWindows(void);
void DPRefreshLittleDiaWindows(void);
void DPPromoteLittleDiaWindow(NSWindow *window);

void DPInstallLittleDiaOver(void);
void DPPutLittleDiaOver(NSWindow *little, NSWindow *window);
BOOL DPLittleDiaIsOver(NSWindow *window);  // Hide Toolbar keeps that window's toolbar hidden meanwhile.

void DPInstallLittleDiaStack(void);
NSDictionary *DPNoteStackForLink(void);
void DPRestoreStack(NSWindow *little, NSDictionary *noted);
NSArray<NSDictionary *> *DPWindowStack(void);  // Normal windows on screen, front to back, with their numbers and owners.
void DPReturnToSource(pid_t pid, NSWindow *little, NSArray<NSDictionary *> *stack);
void DPBringBackPutAway(NSWindow *little);
void DPLinkArrived(void);
BOOL DPHideAgain(void);

void DPInstallLittleDiaBar(void);
// Peek's toolbar uses these too.
NSButton *DPMakeBarButton(NSString *symbol, NSString *label, NSString *key, void (^action)(void));
NSView *DPMakeDivider(void);
void DPMatchPage(NSView *row, id page);
void DPRelayoutLittleDiaBars(void);

NSView *DPMakeAddressView(NSView *title);
void DPRefreshAddressView(NSView *view);
void DPEditLittleDiaAddress(NSWindow *window);
void DPShowLittleDiaNotice(NSWindow *window, NSString *message);

void DPInstallLittleDiaShortcuts(void);
NSString *DPLittleDiaShortcutsProblem(void);

NSString *DPLittleDiaURL(NSWindow *window);
NSDictionary *DPLittleDiaTab(NSWindow *window, NSString *action);
void DPLittleDiaGo(NSWindow *window, SEL action);
void DPLittleDiaNavigate(NSWindow *window, NSString *typed);

NSArray<NSString *> *DPLittleDiaProfiles(void);  // In Dia's order, which DPOpenInProfile's index counts in.
NSImage *DPLittleDiaProfileImage(NSString *name);
void DPOpenInProfile(NSString *url, NSUInteger index, void (^done)(BOOL opened));
