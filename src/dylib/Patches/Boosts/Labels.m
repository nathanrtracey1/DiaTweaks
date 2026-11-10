#import "Patches/Boosts/Boosts.h"
#import "Settings/Settings.h"

// DPLabel wraps, and a wrapping label squeezed by its row's button grows a line per letter.
NSTextField *DPBoostLabel(NSString *text) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:13];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    [label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}

NSAttributedString *DPBoostTitle(NSString *name, NSString *domain, NSFontWeight weight) {
    NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:name attributes:@{
        NSFontAttributeName : [NSFont systemFontOfSize:13 weight:weight], NSForegroundColorAttributeName : NSColor.labelColor,
    }];
    [title appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" (%@)", domain] attributes:@{
        NSFontAttributeName : [NSFont systemFontOfSize:13], NSForegroundColorAttributeName : NSColor.secondaryLabelColor,
    }]];
    return title;
}

NSImageView *DPBoostFavicon(NSString *domain, CGFloat points) {
    NSImageView *icon = DPSymbol(@"globe", points * 0.75, NSColor.secondaryLabelColor);
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSLayoutDimension *side in @[ icon.widthAnchor, icon.heightAnchor ]) [side constraintEqualToConstant:points].active = YES;
    __weak NSImageView *weak = icon;
    DPLoadFavicon(domain, points, ^(NSImage *favicon) {
        if (!favicon) return;
        weak.symbolConfiguration = nil;
        weak.image = favicon;
    });
    return icon;
}
