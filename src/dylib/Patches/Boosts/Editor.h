// The Boost popover for one site, laid out like Arc's: a color pad, a grid of fonts, then Size, Case, Zap and Code.
// Editor.m keeps the state and handles the controls, Popover.m shows and closes it, EditorView.m lays it out from
// Settings' own groups and rows, and the rest make its parts.
#import "Patches/Boosts/Boosts.h"
#import "Settings/Settings.h"

// ColorPad.m: hue from left to right, saturation from bottom to top.
@interface DPBoostColorPad : NSView
@property (nonatomic, copy) NSDictionary *color;  // A boost's color, or nil while the site keeps its own.
@property (nonatomic, copy) void (^picked)(double hue, double sat, BOOL done);  // done: the mouse is up.
@end

@interface DPBoostEditor : NSViewController <NSPopoverDelegate, NSTextViewDelegate>
@property (nonatomic, copy) NSString *domain;
@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, weak) NSWindow *browserWindow;
@property (nonatomic, strong) NSMutableDictionary *boost;  // What the controls show. -save adds the zaps and the code.
@property (nonatomic) BOOL dirty;         // Typing and dragging save a moment after they stop; closing saves what's left.
@property (nonatomic, strong) id clicks;  // The event monitor that closes it, while it's shown.
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *zaps;
@property (nonatomic, weak) id zapping;  // The tab whose clicks hide things, until Escape, Zap again or the popover closing.
@property (nonatomic, strong) NSView *look, *code;  // Its two pages, in a stack: the code takes a wider popover.
@property (nonatomic, strong) NSLayoutConstraint *width;
@property (nonatomic, strong) NSMenuItem *onItem;
@property (nonatomic, strong) DPBoostColorPad *pad;
@property (nonatomic, strong) NSImageView *bulb, *noColor, *bolt;
@property (nonatomic, strong) NSSlider *light;
@property (nonatomic, strong) NSView *fonts;
@property (nonatomic, strong) NSTextField *sizeLabel, *caseLabel, *zapHow;
@property (nonatomic, strong) NSStackView *zapRows;  // A row per thing hidden, in zapScroll.
@property (nonatomic, strong) NSScrollView *zapScroll;
@property (nonatomic, strong) NSTextView *css, *js;
- (instancetype)initWithDomain:(NSString *)domain;
- (void)save;
- (void)saveIn:(NSTimeInterval)delay restarting:(BOOL)restart;
- (void)zap:(id)sender;
- (void)fit;  // The popover takes the size of what's in it, at once.
@end

@interface DPBoostEditor (Layout)  // EditorView.m
- (NSView *)makeContent;
@end

@interface DPBoostEditor (Look)  // Look.m: the color, font, size and case.
- (void)showLook;
- (void)pickHue:(double)hue sat:(double)sat done:(BOOL)done;
@end

@interface DPBoostEditor (Code)  // CodeView.m
- (NSView *)makeCodePage;
@end

@interface DPBoostEditor (ZapList)  // ZapList.m
- (NSView *)makeZapGroup;
- (void)showZapping;  // The Zap row's text and bolt, for whether it's zapping.
- (void)addZapRow:(NSDictionary *)zap animated:(BOOL)animated;
@end

// Tiles.m: Arc's buttons, each a group that runs `action` on `target` when clicked.
NSView *DPBoostTile(NSView *content, NSString *title, id target, SEL action);     // `content` in its middle.
NSView *DPBoostBarTile(NSView *leading, NSView *trailing, NSString *title, id target, SEL action);
NSView *DPBoostTileRow(NSArray<NSView *> *tiles);  // Side by side, as wide as each other.
NSTextField *DPBoostTileLabel(NSString *text);
NSButton *DPBoostIconButton(NSString *symbol, NSString *label, id target, SEL action);

// FontGrid.m: twenty fonts as "Aa", four rows of five. Each button sends `action` with the family as its identifier.
NSView *DPBoostFontGrid(id target, SEL action);
void DPShowBoostFont(NSView *grid, NSString *family);

// Drawer.m: a row under a line like a group's, which opens and closes.
NSView *DPDrawerRow(NSView *content, BOOL open);
@interface DPBoostEditor (Drawer)
- (void)open:(BOOL)open row:(NSView *)row done:(void (^)(void))done;
@end
