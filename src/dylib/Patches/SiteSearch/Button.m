#import "SiteSearch.h"

static char DPButtonKey, DPGoAlphaKey;

// Where Return goes with a site chosen: the site's name and ↩ on its color, in place of Dia's Go button, which says
// Google, or turns into an arrow for a question when it thinks the words are one.
@interface DPSiteButton : NSView
@property(strong) NSTextField *label;
@property(strong) NSImageView *glyph;
@property(nonatomic, strong) NSColor *color;
@property(copy) void (^action)(void);
@end

@implementation DPSiteButton
- (instancetype)init {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    _label = [NSTextField labelWithString:@""];
    _label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    _glyph = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"return" accessibilityDescription:@"Return"] ?: [NSImage new]];
    _glyph.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:11 weight:NSFontWeightSemibold];
    [self addSubview:_label];
    [self addSubview:_glyph];
    return self;
}
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer {
    self.layer.backgroundColor = self.color.CGColor;
    self.layer.cornerRadius = NSHeight(self.bounds) / 2;
}
// Dark text on a light color, such as Walmart's yellow; white on the rest.
- (void)setColor:(NSColor *)color {
    _color = color;
    NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    CGFloat light = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent;
    NSColor *ink = light > 0.65 ? [NSColor colorWithWhite:0.1 alpha:1] : NSColor.whiteColor;
    self.label.textColor = ink;
    self.glyph.contentTintColor = [ink colorWithAlphaComponent:0.75];
    self.needsDisplay = YES;
}
- (NSSize)fitInHeight:(CGFloat)height {
    [self.label sizeToFit];
    NSSize text = self.label.frame.size, glyph = self.glyph.intrinsicContentSize;
    self.label.frame = NSMakeRect(14, round((height - text.height) / 2), text.width, text.height);
    self.glyph.frame = NSMakeRect(NSMaxX(self.label.frame) + 5, round((height - glyph.height) / 2), glyph.width, glyph.height);
    return NSMakeSize(ceil(NSMaxX(self.glyph.frame) + 12), height);
}
- (void)mouseDown:(NSEvent *)event {}
- (void)mouseUp:(NSEvent *)event {
    if (NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], self.bounds) && self.action) self.action();
}
- (NSView *)hitTest:(NSPoint)point { return NSPointInRect(point, self.frame) ? self : nil; }
@end

static NSView *DPBarOf(NSView *view) {
    while (view && !DPIsKind(view, DPDiaCommandBar)) view = view.superview;
    return view;
}

// Dia's Go button: the last item in the command bar's toolbar, beside the field or under it.
static NSView *DPGoOf(NSView *bar) {
    NSView *toolbar = DPFindView(bar, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaCommandBarToolbar); });
    NSStackView *stack = toolbar.subviews.firstObject;
    return [stack isKindOfClass:NSStackView.class] ? stack.views.lastObject : nil;
}

void DPShowSiteButton(NSTextView *text, DPSite *site, NSColor *color) {
    NSView *bar = DPBarOf(text), *go = DPGoOf(bar);
    DPSiteButton *button = DPGet(text, &DPButtonKey);
    if (!site) {
        [button removeFromSuperview];
        DPSet(text, &DPButtonKey, nil);
        NSNumber *alpha = DPGet(go, &DPGoAlphaKey);
        if (alpha) go.alphaValue = alpha.doubleValue;
        DPSet(go, &DPGoAlphaKey, nil);
        return;
    }
    if (!go || !bar) return;
    if (!button) {
        button = [DPSiteButton new];
        __weak NSTextView *field = text;
        button.action = ^{ [field doCommandBySelector:@selector(insertNewline:)]; };
        DPSet(text, &DPButtonKey, button);
    }
    if (!DPGet(go, &DPGoAlphaKey)) DPSet(go, &DPGoAlphaKey, @(go.alphaValue));
    go.alphaValue = 0;
    button.color = color;
    button.label.stringValue = site.name;
    NSRect goFrame = [go convertRect:go.bounds toView:bar];
    CGFloat height = MAX(NSHeight(goFrame), 28);
    NSSize size = [button fitInHeight:height];
    button.frame = NSMakeRect(NSMaxX(goFrame) - size.width, NSMidY(goFrame) - height / 2, size.width, height);
    if (button.superview != bar) [bar addSubview:button positioned:NSWindowAbove relativeTo:nil];
}

// Dia changes Go as the words change, and brings it back as it lays the bar out; the site's button goes back over it.
void DPRefreshSiteButton(NSTextView *text) {
    DPSiteButton *button = DPGet(text, &DPButtonKey);
    DPSite *site = DPSiteSearch.on ? DPSiteOfField(text) : nil;
    if (site && button) DPShowSiteButton(text, site, button.color);
}

static void DPBar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPBar_layout, self);
    NSTextView *text = (NSTextView *)DPFindView(self, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextView.class]; });
    DPRefreshSiteButton(text);
    DPRefreshGlow(text);  // The bar shrinks once the suggestions hide.
}

void DPInstallSiteButton(void) {
    DPHook(DPDiaCommandBar, @selector(layout), (IMP)DPBar_layout);
}
