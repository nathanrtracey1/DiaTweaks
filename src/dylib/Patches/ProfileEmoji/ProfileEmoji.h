#import "StdPatch/StdPatch.h"

extern DPPatch DPProfileEmoji;
extern NSString *const DPSymbolPrefix;  // Saved icons starting with it name an SF Symbol; the rest are emoji.

NSString *DPSavedIcon(NSString *spaceID);
void DPSaveIcon(NSString *spaceID, NSString *icon);  // nil removes it.
void DPAddEmojiRow(NSViewController *pane);

NSImage *DPSymbolNamed(NSString *name);  // Public or private; nil if this macOS has neither.
NSArray<NSString *> *DPSymbolsMatching(NSString *query);  // Every symbol for an empty query.

// Every SF Symbol in a searchable grid, for a popover.
@interface DPSymbolPicker : NSViewController
@property(copy) NSString *chosen;  // nil for none.
@property(copy) void (^onPick)(NSString *name);  // nil removes the symbol.
@end
