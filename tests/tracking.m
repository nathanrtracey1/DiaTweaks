#import "Commands/GroupTabs/Tracking.m"

// Stand-ins for Dia's classes, found by name as in Dia.
@interface ArcBrowser : NSObject
@end
@implementation ArcBrowser
- (void)setDelegate:(id)delegate {}
- (void)setWindow:(NSWindow *)window {}
- (id)createWebContents:(id)configuration { return [NSClassFromString(@"ArcWebContents") new]; }
- (void)takeOwnershipOfWebContents:(id)contents {}
@end

@interface _TtC3ADK15ChromiumBrowser : NSObject
@end
@implementation _TtC3ADK15ChromiumBrowser
- (void)browser:(id)browser didRestoreWebContents:(id)contents withSessionId:(id)session {}
- (void)browser:(id)browser didCreateNewWebContents:(id)contents isActive:(BOOL)active {}
@end

@interface ArcWebContents : NSObject
@property long long sessionId;
- (id)clone;
@end
@implementation ArcWebContents
- (id)clone { return [ArcWebContents new]; }
@end

@interface _TtC3ADK18WebContentChromium : NSObject
@end
@implementation _TtC3ADK18WebContentChromium
- (void)webContents:(id)webContents didCreateNewWebContent:(id)newContents targetURL:(NSURL *)url disposition:(NSInteger)disposition {}
@end

void DPOnLaunch(void (^block)(void)) { block(); }
void DPInstallGroupMenus(void) {}
void DPInstallGroupTabsShortcut(void) {}

static int failures;

static void expect(BOOL ok, NSString *what) {
    if (ok) return;
    failures++;
    printf("FAIL %s\n", what.UTF8String);
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        DPInstallGroupTabs();
        ArcBrowser *browser = [ArcBrowser new];
        id page = [browser createWebContents:nil], ui = [_TtC3ADK18WebContentChromium new];
        expect(DPBrowserOfContents(page) == browser, @"a tab Dia creates belongs to the browser that made it");

        id linked = [ArcWebContents new];
        [ui webContents:page didCreateNewWebContent:linked targetURL:nil disposition:2];
        expect(DPBrowserOfContents(linked) == browser, @"a tab a link or a script opens belongs to its opener's browser");
        expect([DPTrackedContents(browser) containsObject:linked], @"and Group Tabs, Tidy Tabs and the rest see it");

        id nested = [ArcWebContents new];
        [ui webContents:linked didCreateNewWebContent:nested targetURL:nil disposition:3];
        expect(DPBrowserOfContents(nested) == browser, @"so does one opened from a tab that was itself opened that way");

        id stranger = [ArcWebContents new], fromStranger = [ArcWebContents new];
        [ui webContents:stranger didCreateNewWebContent:fromStranger targetURL:nil disposition:2];
        expect(DPBrowserOfContents(fromStranger) == nil, @"a page nobody told us about opens tabs nobody is told about");

        id copy = [page clone];
        expect(DPBrowserOfContents(copy) == browser, @"a duplicate belongs to its original's browser");
        expect(DPBrowserOfContents([stranger clone]) == nil, @"and a duplicate of an unknown page stays unknown");
    }
    if (failures) return 1;
    puts("PASS: tabs opened by a link, a script or a duplicate are tracked");
    return 0;
}
