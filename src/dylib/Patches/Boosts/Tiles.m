#import "Patches/Boosts/Editor.h"

// Arc's buttons are filled tiles. Each is a Settings group in a link row, which takes the click and reads as a button.
static NSView *DPTile(NSView *row, NSString *title, id target, SEL action) {
    __weak id weak = target;  // The editor holds its view, and so the tile.
    return DPLinkRow(DPGroup(@[ row ]), title, ^{
        id target = weak;
        if (target) [NSApp sendAction:action to:target from:nil];
    });
}

NSView *DPBoostTile(NSView *content, NSString *title, id target, SEL action) {
    NSView *row = [NSView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.centerXAnchor constraintEqualToAnchor:row.centerXAnchor],
        [content.topAnchor constraintEqualToAnchor:row.topAnchor constant:10], [content.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-10],
    ]];
    return DPTile(row, title, target, action);
}

NSView *DPBoostBarTile(NSView *leading, NSView *trailing, NSString *title, id target, SEL action) {
    return DPTile(DPRow(leading, trailing), title, target, action);
}

NSView *DPBoostTileRow(NSArray<NSView *> *tiles) {
    NSStackView *row = [NSStackView stackViewWithViews:tiles];
    row.distribution = NSStackViewDistributionFillEqually;
    row.spacing = 8;
    return row;
}

NSTextField *DPBoostTileLabel(NSString *text) {
    NSTextField *label = DPBoostLabel(text);
    label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    return label;
}

NSButton *DPBoostIconButton(NSString *symbol, NSString *label, id target, SEL action) {
    NSButton *button = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:label] target:target action:action];
    button.bordered = NO;
    button.contentTintColor = NSColor.secondaryLabelColor;
    return button;
}
