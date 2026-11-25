#import "Patches/Boosts/Boosts.h"

// A paintbrush styled like the address field's own buttons: 22 points square, a 5-point radius and a faint fill under
// the pointer. It's pink while the site has a Boost on.
@interface DPBoostButton ()
@property (nonatomic, copy) NSString *symbol;  // Set only when it changes: a new image lays the field out again.
@property (nonatomic) BOOL hovered;
@property (nonatomic, strong) CALayer *fill;
@end

@implementation DPBoostButton

- (instancetype)init {
    if (!(self = [super initWithFrame:NSMakeRect(0, 0, 22, 22)])) return nil;
    self.bordered = NO;
    self.wantsLayer = YES;
    self.fill = [CALayer layer];
    self.fill.cornerRadius = 5;
    [self.layer addSublayer:self.fill];
    self.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightRegular];
    self.imagePosition = NSImageOnly;
    self.accessibilityLabel = @"Boost This Site";
    self.target = self;
    self.action = @selector(open:);
    [self.widthAnchor constraintEqualToConstant:22].active = YES;
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
    return self;
}

- (void)open:(id)sender {
    NSString *domain = DPFrontDomain();
    if (!domain) return NSBeep();  // Not a web page.
    DPShowBoostEditor(domain);
}

- (void)sync {
    BOOL active = [DPBoostFor(DPFrontDomain())[@"enabled"] boolValue];
    NSString *symbol = active ? @"paintbrush.pointed.fill" : @"paintbrush.pointed";
    if ([symbol isEqual:self.symbol]) return;
    self.symbol = symbol;
    self.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:@"Boost This Site"];
    [self restyle];
}

- (void)restyle {
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        BOOL active = [self.symbol hasSuffix:@".fill"];
        self.contentTintColor = active ? NSColor.systemPinkColor : NSColor.secondaryLabelColor;
        self.fill.backgroundColor = self.hovered ? [NSColor.labelColor colorWithAlphaComponent:0.06].CGColor : NSColor.clearColor.CGColor;
    }];
}

// The field's stack gives it its full height, where Dia's own buttons keep to 22 points, so the fill sits in the middle.
- (void)layout {
    [super layout];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.fill.frame = NSMakeRect(0, round((NSHeight(self.bounds) - 22) / 2), 22, 22);
    [CATransaction commit];
}

- (void)setHovered:(BOOL)hovered { _hovered = hovered; [self restyle]; }
- (void)mouseEntered:(NSEvent *)event { self.hovered = YES; }
- (void)mouseExited:(NSEvent *)event { self.hovered = NO; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self restyle]; }
@end
