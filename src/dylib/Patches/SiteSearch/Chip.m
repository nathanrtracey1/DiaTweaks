#import "SiteSearch.h"

static char DPChipKey, DPPaddingKey;

#define DPDiaIconContainer   "_TtC15BoostCommandBar17IconContainerView"

// The site's icon and name in a capsule of its color.
@interface DPSiteChip : NSView
@property(strong) NSImageView *icon;
@property(strong) NSTextField *label;
@property(strong) NSColor *color;
@end

@implementation DPSiteChip
- (instancetype)init {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    _icon = [NSImageView new];
    _icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    _label = [NSTextField labelWithString:@""];
    _label.textColor = NSColor.labelColor;
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_icon];
    [self addSubview:_label];
    return self;
}
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer {
    self.layer.backgroundColor = [self.color colorWithAlphaComponent:0.2].CGColor;
    self.layer.borderColor = [self.color colorWithAlphaComponent:0.55].CGColor;
    self.layer.borderWidth = 1;
    self.layer.cornerRadius = NSHeight(self.bounds) / 2;
}
- (NSSize)fitWithFont:(NSFont *)font {
    self.label.font = [NSFont systemFontOfSize:font.pointSize - 1 weight:NSFontWeightMedium];
    [self.label sizeToFit];
    CGFloat height = ceil(font.pointSize + 9), side = round(font.pointSize);
    NSSize text = self.label.frame.size;
    self.icon.frame = NSMakeRect(7, (height - side) / 2, side, side);
    self.label.frame = NSMakeRect(NSMaxX(self.icon.frame) + 5, round((height - text.height) / 2), text.width, text.height);
    return NSMakeSize(ceil(NSMaxX(self.label.frame) + 9), height);
}
@end

static NSView *DPInputOf(NSView *view) {
    while (view && !DPIsKind(view, DPDiaCommandBarInput)) view = view.superview;
    return view;
}

static NSView *DPFieldIconOf(NSView *text) {
    return DPFindView(DPInputOf(text), ^BOOL(NSView *view) { return DPIsKind(view, DPDiaIconContainer); });
}

// The site's chip where the field's icon goes, Dia's magnifying glass or globe hidden under it, and the text moved over
// to start after it.
void DPShowChip(NSTextView *text, DPSite *site, NSImage *icon, NSColor *color) {
    DPSiteChip *chip = DPGet(text, &DPChipKey);
    NSView *input = DPInputOf(text), *fieldIcon = DPFieldIconOf(text);
    text.needsDisplay = YES;  // For the placeholder, which goes while a site is chosen.
    if (!site) {
        [chip removeFromSuperview];
        DPSet(text, &DPChipKey, nil);
        NSNumber *padding = DPGet(text, &DPPaddingKey);
        if (padding) text.textContainer.lineFragmentPadding = padding.doubleValue;
        DPSet(text, &DPPaddingKey, nil);
        fieldIcon.hidden = NO;
        return;
    }
    if (!input) return;
    if (!chip) {
        chip = [DPSiteChip new];
        DPSet(text, &DPChipKey, chip);
        DPSet(text, &DPPaddingKey, @(text.textContainer.lineFragmentPadding));
    }
    fieldIcon.hidden = YES;
    chip.color = color;
    chip.needsDisplay = YES;
    chip.label.stringValue = site.name;
    chip.icon.image = icon;
    NSFont *font = text.font ?: [NSFont systemFontOfSize:14];
    NSSize size = [chip fitWithFont:font];
    // Level with the first line of text, which sits higher than the middle of a field that grows.
    CGFloat line = font.ascender - font.descender + font.leading;
    NSPoint middle = [text convertPoint:NSMakePoint(0, text.textContainerInset.height + line / 2) toView:input];
    CGFloat left = fieldIcon ? NSMinX(fieldIcon.frame) : [text convertPoint:NSZeroPoint toView:input].x;
    NSRect frame = NSMakeRect(left, round(middle.y - size.height / 2), size.width, size.height);
    if (!NSEqualRects(chip.frame, frame)) chip.frame = frame;
    if (chip.superview != input) [input addSubview:chip positioned:NSWindowAbove relativeTo:nil];
    // Measured where the text starts now: Dia moves the field over into the space its icon leaves.
    CGFloat textLeft = [text convertPoint:NSMakePoint(text.textContainerInset.width, 0) toView:input].x;
    CGFloat padding = [DPGet(text, &DPPaddingKey) doubleValue] + MAX(0, NSMaxX(frame) + 8 - textLeft);
    if (text.textContainer.lineFragmentPadding != padding) text.textContainer.lineFragmentPadding = padding;
}

// Dia lays the field out again as the words change and when its icon hides; the chip and the text's start follow.
static void DPInput_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPInput_layout, self);
    NSTextView *text = (NSTextView *)DPFindView(self, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextView.class]; });
    DPSiteChip *chip = DPGet(text, &DPChipKey);
    DPSite *site = DPSiteSearch.on ? DPSiteOfField(text) : nil;
    if (site && chip) DPShowChip(text, site, chip.icon.image, chip.color);
}

// Dia shows its icon again as the words change; it stays hidden under the chip.
static void DPFieldIcon_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    NSTextView *text = (NSTextView *)DPFindView(DPInputOf(self), ^BOOL(NSView *view) { return [view isKindOfClass:NSTextView.class]; });
    DPCallOriginal(DPFieldIcon_setHidden, self, hidden || (DPSiteSearch.on && DPSiteOfField(text)));
}

void DPInstallSiteChip(void) {
    DPHook(DPDiaIconContainer, @selector(setHidden:), (IMP)DPFieldIcon_setHidden);
    DPHook(DPDiaCommandBarInput, @selector(layout), (IMP)DPInput_layout);
}
