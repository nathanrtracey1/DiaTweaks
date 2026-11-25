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
    for (NSString *brand in brands) assert(DPProviderIcon(@{@"brand": brand}).image.isValid);
    puts("PASS packaged provider logos and icon creation");
} }
