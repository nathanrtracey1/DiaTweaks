#import "Patches/Boosts/Editor.h"

static const CGFloat DPFontCell = 26, DPFontRows = 4, DPFontColumns = 5;

// Arc's grid shows twenty fonts of its own. These come with every Mac: sans serifs, then serifs, then the odd ones.
static NSArray<NSString *> *DPFontFamilies(void) {
    return @[ @"Helvetica Neue", @"Avenir Next", @"Futura", @"Gill Sans", @"Optima",
              @"Verdana", @"Trebuchet MS", @"Arial Rounded MT Bold", @"American Typewriter", @"Rockwell",
              @"Georgia", @"Palatino", @"Baskerville", @"Didot", @"Hoefler Text",
              @"Snell Roundhand", @"Bradley Hand", @"Marker Felt", @"Menlo", @"Papyrus" ];
}

NSView *DPBoostFontGrid(id target, SEL action) {
    NSArray<NSString *> *families = DPFontFamilies();
    NSMutableArray<NSArray<NSView *> *> *rows = [NSMutableArray new];
    for (NSUInteger first = 0; first < families.count; first += DPFontColumns) {
        NSMutableArray<NSView *> *row = [NSMutableArray new];
        for (NSString *family in [families subarrayWithRange:NSMakeRange(first, DPFontColumns)]) {
            NSButton *button = [NSButton buttonWithTitle:@"Aa" target:target action:action];
            button.bordered = NO;
            button.font = [NSFontManager.sharedFontManager fontWithFamily:family traits:0 weight:5 size:12] ?: [NSFont systemFontOfSize:12];
            button.identifier = family;
            button.accessibilityLabel = family;
            DPSetHint(button, family);
            [row addObject:button];
        }
        [rows addObject:row];
    }
    NSGridView *grid = [NSGridView gridViewWithViews:rows];
    grid.rowSpacing = grid.columnSpacing = 0;
    grid.xPlacement = grid.yPlacement = NSGridCellPlacementCenter;
    for (NSInteger column = 0; column < DPFontColumns; column++) [grid columnAtIndex:column].width = DPFontCell;
    for (NSInteger row = 0; row < DPFontRows; row++) [grid rowAtIndex:row].height = DPFontCell;
    NSView *row = [NSView new];
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:grid];
    [NSLayoutConstraint activateConstraints:@[
        [grid.centerXAnchor constraintEqualToAnchor:row.centerXAnchor],
        [grid.topAnchor constraintEqualToAnchor:row.topAnchor constant:8], [grid.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-8],
    ]];
    return DPGroup(@[ row ]);
}

// The font that's on is pink, like the paintbrush while a site has a Boost.
void DPShowBoostFont(NSView *grid, NSString *family) {
    NSView *found = DPFindView(grid, ^BOOL(NSView *view) { return [view isKindOfClass:NSGridView.class]; });
    for (NSButton *button in found.subviews)
        button.contentTintColor = [button.identifier isEqual:family] ? NSColor.systemPinkColor : NSColor.secondaryLabelColor;
}
