#import "Patches/TidyTabs/TidyTabs.h"
#import "Patches/CommandBar/Tabs.h"

@interface DPFakeTab : NSObject
@property NSString *URL, *title;
@property (getter=isPinned) BOOL pinned;
@end
@implementation DPFakeTab
@end

@interface DPFakeScriptWindow : NSObject
@property NSString *windowId;
@property NSArray *appleScriptTabs;
@end
@implementation DPFakeScriptWindow
@end

@interface DPFakeDelegate : NSObject <NSApplicationDelegate>
@property NSArray *appleScriptWindows;
@end
@implementation DPFakeDelegate
@end

NSArray<NSView *> *DPFindViews(const char *className) { return @[]; }
NSView *DPTidySeparatorIn(NSView *list) { return nil; }
NSScrollView *DPTidyListScroll(NSView *list) { return nil; }

static int failures;

static void expectEqual(id got, id want, NSString *what) {
    if ([got isEqual:want] || got == want) return;
    failures++;
    printf("FAIL %s: got %s, want %s\n", what.UTF8String, [[got description] UTF8String], [[want description] UTF8String]);
}

static DPFakeTab *tab(NSString *url, NSString *title, BOOL pinned) {
    DPFakeTab *tab = [DPFakeTab new];
    tab.URL = url;
    tab.title = title;
    tab.pinned = pinned;
    return tab;
}

static DPFakeScriptWindow *scripted(NSString *windowID, NSArray *tabs) {
    DPFakeScriptWindow *window = [DPFakeScriptWindow new];
    window.windowId = windowID;
    window.appleScriptTabs = tabs;
    return window;
}

static NSWindow *window(NSString *identifier) {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300)
        styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    window.identifier = identifier;
    window.releasedWhenClosed = NO;
    return window;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        DPFakeDelegate *delegate = [DPFakeDelegate new];
        NSApp.delegate = delegate;

        NSWindow *older = window(@"A"), *newer = window(@"B"), *stranger = window(@"C");
        delegate.appleScriptWindows = @[
            scripted(@"A", @[ tab(@"https://a.example/1", @"A one", NO), tab(@"https://shared.example/", @"Shared", NO), tab(@"https://a.example/2", @"A two", NO) ]),
            scripted(@"B", @[ tab(@"https://shared.example/", @"Shared", YES), tab(@"https://b.example/1", @"B one", NO), tab(@"https://b.example/2", nil, NO), tab(@"", @"No address", NO) ]),
        ];

        expectEqual(DPTidyLooseTabs(older), (@{ @"https://a.example/1": @"A one", @"https://shared.example/": @"Shared", @"https://a.example/2": @"A two" }),
            @"the first window lists its own tabs");
        expectEqual(DPTidyLooseTabs(newer), (@{ @"https://b.example/1": @"B one", @"https://b.example/2": @"https://b.example/2" }),
            @"the second window lists its own tabs, not the first window's, and keeps a favorite out");
        expectEqual(DPTidyLooseTabs(stranger), @{}, @"a window Dia doesn't script has no loose tabs");
        expectEqual(DPTidyLooseTabs(nil), @{}, @"no window has no loose tabs");

        delegate.appleScriptWindows = @[ scripted(@"B", (id)@"not a list") ];
        expectEqual(DPTidyLooseTabs(newer), @{}, @"a window without a tab list has no loose tabs");
        delegate.appleScriptWindows = @[];
        expectEqual(DPTidyLooseTabs(newer), @{}, @"no scripted windows means no loose tabs");
    }
    if (!failures) printf("all Tidy Tabs checks passed\n");
    return failures ? 1 : 0;
}
