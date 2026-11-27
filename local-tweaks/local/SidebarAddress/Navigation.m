#import "SidebarAddress.h"
#import "Patches/LittleDia/LittleDia.h"

static const CGFloat DPNavigationButton = 28, DPNavigationGap = 2;
// Dia's own labels for the toolbar buttons these stand in for.
static NSString *const DPNavigationLabels[] = {@"Go back", @"Go forward", @"Reload this page"};
static NSString *const DPNavigationSymbols[] = {@"chevron.left", @"chevron.right", @"arrow.clockwise"};

@interface DPSidebarNavigation : NSView
@property (nonatomic) NSArray<NSButton *> *buttons;
@end

@implementation DPSidebarNavigation

- (instancetype)init {
    if (!(self = [super initWithFrame:(NSRect){NSZeroPoint, DPSidebarNavigationSize()}])) return nil;
    NSMutableArray<NSButton *> *buttons = [NSMutableArray new];
    __weak DPSidebarNavigation *weak = self;
    for (NSUInteger i = 0; i < 3; i++) {
        NSString *label = DPNavigationLabels[i];
        NSButton *button = DPMakeBarButton(DPNavigationSymbols[i], label, nil, ^{
            DPPressToolbarControl(DPToolbarControl(DPToolbarFor(weak.window), label));
        });
        button.frame = NSMakeRect(i * (DPNavigationButton + DPNavigationGap), 0, DPNavigationButton, DPNavigationButton);
        [self addSubview:button];
        [buttons addObject:button];
    }
    _buttons = buttons;
    return self;
}

- (void)refresh {
    NSView *toolbar = DPToolbarFor(self.window);
    [self.buttons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger i, BOOL *stop) {
        button.enabled = DPToolbarControlEnabled(DPToolbarControl(toolbar, DPNavigationLabels[i]));
    }];
}

@end

NSView *DPMakeSidebarNavigation(void) { return [DPSidebarNavigation new]; }
BOOL DPIsSidebarNavigation(NSView *view) { return [view isKindOfClass:DPSidebarNavigation.class]; }
NSSize DPSidebarNavigationSize(void) { return NSMakeSize(3 * DPNavigationButton + 2 * DPNavigationGap, DPNavigationButton); }
void DPRefreshSidebarNavigation(NSView *navigation) { if (DPIsSidebarNavigation(navigation)) [(DPSidebarNavigation *)navigation refresh]; }
