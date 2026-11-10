// The Boost popover for one site. Editor.m keeps the state and handles the controls, Popover.m shows and closes it,
// EditorView.m lays it out from Settings' own rows and groups, and ZapList.m and Drawer.m make its list of what's hidden.
#import "Patches/Boosts/Boosts.h"
#import "Settings/Settings.h"

@interface DPBoostEditor : NSViewController <NSPopoverDelegate, NSTextViewDelegate>
@property (nonatomic, copy) NSString *domain;
@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, weak) NSWindow *browserWindow;
@property (nonatomic) BOOL dirty;         // Typing saves a moment after it stops; closing saves what's left.
@property (nonatomic, strong) id clicks;  // The event monitor that closes it, while it's shown.
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *zaps;
@property (nonatomic, weak) id zapping;  // The tab whose clicks hide things, until Escape, Done or the popover closing.
@property (nonatomic, strong) NSSwitch *enabled;
@property (nonatomic, strong) NSStackView *zapRows;  // A row per thing hidden, in zapScroll.
@property (nonatomic, strong) NSScrollView *zapScroll;
@property (nonatomic, strong) NSTextField *zapHow;
@property (nonatomic, strong) NSButton *zapButton;
@property (nonatomic, strong) NSPopUpButton *font;
@property (nonatomic, strong) NSTextView *css, *js;
- (instancetype)initWithDomain:(NSString *)domain;
- (void)save;
@end

@interface DPBoostEditor (Layout)  // EditorView.m
- (NSView *)makeContent:(NSDictionary *)boost;
@end

@interface DPBoostEditor (ZapList)  // ZapList.m
- (NSView *)makeZapGroup;
- (void)showZapping;  // The Zap row's text and button, for whether it's zapping.
- (void)addZapRow:(NSDictionary *)zap animated:(BOOL)animated;
@end

// Drawer.m: a row under a line like a group's, which opens and closes.
NSView *DPDrawerRow(NSView *content, BOOL open);
@interface DPBoostEditor (Drawer)
- (void)open:(BOOL)open row:(NSView *)row done:(void (^)(void))done;
@end
