#import "Patches/DiaChatModel/ProviderUI.h"
#include <assert.h>
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation DPChatProviders
+ (NSString *)brand:(NSDictionary *)provider { return provider[@"brand"]; }
@end
NSImageView *DPSymbol(NSString *name, CGFloat size, NSColor *color) {
    NSImageView *view = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:name accessibilityDescription:nil]];
    view.contentTintColor = color; return view;
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    for (NSString *brand in @[@"chatgpt", @"openai", @"anthropic", @"google"])
        assert(DPProviderLogo(brand).isValid);  // A fallback symbol must not hide missing packaged assets.
    assert(DPProviderLogo(@"openai") == DPProviderLogo(@"chatgpt"));
    NSArray *brands = @[@"apple", @"chatgpt", @"openai", @"anthropic", @"google", @"custom"];
    NSArray *names = @[@"Apple", @"ChatGPT", @"OpenAI", @"Anthropic", @"Google", @"Custom"];
    NSImage *proof = [[NSImage alloc] initWithSize:NSMakeSize(540, 160)];
    [proof lockFocus];
    for (NSUInteger row = 0; row < 2; row++) {
        NSAppearance *appearance = [NSAppearance appearanceNamed:row ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
        [appearance performAsCurrentDrawingAppearance:^{
            [(row ? [NSColor colorWithWhite:0.13 alpha:1] : NSColor.whiteColor) setFill];
            NSRectFill(NSMakeRect(0, row * 80, 540, 80));
            for (NSUInteger column = 0; column < brands.count; column++) {
                NSImageView *view = DPProviderIcon(@{@"brand": brands[column]});
                view.appearance = appearance; view.frame = NSMakeRect(0, 0, 18, 18);
                assert(view.image.isValid);
                NSImage *glyph = [[NSImage alloc] initWithSize:NSMakeSize(18, 18)];
                [glyph lockFocus];
                NSRect rect = NSMakeRect(0, 0, 18, 18);
                NSRectFillUsingOperation(rect, NSCompositingOperationClear);
                [view.image drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
                if (view.image.isTemplate) {
                    [(row ? NSColor.whiteColor : NSColor.blackColor) setFill];
                    NSRectFillUsingOperation(rect, NSCompositingOperationSourceIn);
                }
                [glyph unlockFocus];
                [glyph drawInRect:NSMakeRect(column * 90 + 36, row * 80 + 40, 18, 18)];
                [names[column] drawInRect:NSMakeRect(column * 90 + 12, row * 80 + 13, 75, 18)
                    withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:11],NSForegroundColorAttributeName:row ? NSColor.whiteColor : NSColor.blackColor}];
            }
        }];
    }
    [proof unlockFocus];
    NSString *path = NSProcessInfo.processInfo.environment[@"DIATWEAKS_ICON_PROOF"];
    if (path) {
        NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:proof.TIFFRepresentation];
        assert([[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES]);
    }
    puts("PASS provider logo decoding and light/dark rendering");
} }
