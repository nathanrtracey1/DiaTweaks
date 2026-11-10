#import "ProfileEmoji.h"

static NSString *const DPNoSymbol = @"";  // The first cell while nothing's searched, which removes the symbol.
static const CGFloat DPCell = 32, DPGap = 2, DPInset = 8, DPColumns = 8;

@interface DPSymbolCell : NSCollectionViewItem
@end

@implementation DPSymbolCell
- (void)loadView {
    NSImageView *image = [NSImageView new];
    image.imageScaling = NSImageScaleNone;
    image.wantsLayer = YES;
    image.layer.cornerRadius = 6;
    self.view = self.imageView = image;
}

- (void)setSelected:(BOOL)selected {
    super.selected = selected;
    self.view.layer.backgroundColor = selected ? NSColor.selectedContentBackgroundColor.CGColor : nil;
}
@end

@interface DPSymbolPicker () <NSCollectionViewDataSource, NSCollectionViewDelegate, NSSearchFieldDelegate>
@property(strong) NSSearchField *search;
@property(strong) NSCollectionView *grid;
@property(strong) NSTextField *empty;
@property(copy) NSArray<NSString *> *names;
@end

@implementation DPSymbolPicker
- (void)loadView {
    CGFloat width = DPColumns * DPCell + (DPColumns - 1) * DPGap + 2 * DPInset + 2;
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, width + 16, 340)];
    self.search = [[NSSearchField alloc] initWithFrame:NSMakeRect(8, 304, width, 28)];
    self.search.placeholderString = @"Search Symbols";
    self.search.delegate = self;

    NSCollectionViewFlowLayout *layout = [NSCollectionViewFlowLayout new];
    layout.itemSize = NSMakeSize(DPCell, DPCell);
    layout.minimumInteritemSpacing = layout.minimumLineSpacing = DPGap;
    layout.sectionInset = NSEdgeInsetsMake(DPInset, DPInset, DPInset, DPInset);
    self.grid = [NSCollectionView new];
    self.grid.collectionViewLayout = layout;
    self.grid.dataSource = self;
    self.grid.delegate = self;
    self.grid.selectable = YES;
    self.grid.backgroundColors = @[ NSColor.clearColor ];
    [self.grid registerClass:DPSymbolCell.class forItemWithIdentifier:@"symbol"];
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(8, 8, width, 288)];
    scroll.documentView = self.grid;
    scroll.hasVerticalScroller = YES;
    scroll.scrollerStyle = NSScrollerStyleOverlay;  // A legacy scroller would take the eighth column.
    scroll.drawsBackground = NO;

    self.empty = [NSTextField labelWithString:@"No Symbols"];
    self.empty.textColor = NSColor.secondaryLabelColor;
    [self.empty sizeToFit];
    [self.empty setFrameOrigin:NSMakePoint(round(NSMidX(scroll.frame) - NSWidth(self.empty.frame) / 2), NSMidY(scroll.frame))];
    for (NSView *sub in @[ self.search, scroll, self.empty ]) [view addSubview:sub];
    self.view = view;
    [self show:@""];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self.view.window makeFirstResponder:self.search];
    NSUInteger chosen = [self.names indexOfObject:self.chosen ?: DPNoSymbol];
    if (chosen != NSNotFound) [self.grid scrollToItemsAtIndexPaths:[NSSet setWithObject:[NSIndexPath indexPathForItem:chosen inSection:0]] scrollPosition:NSCollectionViewScrollPositionCenteredVertically];
}

- (void)show:(NSString *)query {
    NSArray<NSString *> *found = DPSymbolsMatching(query);
    self.names = query.length ? found : [@[ DPNoSymbol ] arrayByAddingObjectsFromArray:found];
    self.empty.hidden = self.names.count > 0;
    [self.grid reloadData];
}

- (void)controlTextDidChange:(NSNotification *)note {
    [self show:self.search.stringValue];
}

// Return picks the first match, so a search and Return is enough.
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    if (command != @selector(insertNewline:) || !self.names.count) return NO;
    self.onPick(self.names.firstObject.length ? self.names.firstObject : nil);
    return YES;
}

- (NSInteger)collectionView:(NSCollectionView *)view numberOfItemsInSection:(NSInteger)section {
    return self.names.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)view itemForRepresentedObjectAtIndexPath:(NSIndexPath *)path {
    DPSymbolCell *cell = [view makeItemWithIdentifier:@"symbol" forIndexPath:path];
    NSString *name = self.names[path.item];
    NSImage *image = DPSymbolNamed(name.length ? name : @"circle.slash");
    cell.imageView.image = [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:15 weight:NSFontWeightRegular]];
    BOOL chosen = name.length ? [name isEqual:self.chosen] : !self.chosen;
    cell.imageView.contentTintColor = chosen ? NSColor.controlAccentColor : NSColor.secondaryLabelColor;
    cell.view.toolTip = cell.imageView.accessibilityLabel = name.length ? name : @"None";
    return cell;
}

- (void)collectionView:(NSCollectionView *)view didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)paths {
    NSString *name = self.names[paths.anyObject.item];
    self.onPick(name.length ? name : nil);
}
@end
