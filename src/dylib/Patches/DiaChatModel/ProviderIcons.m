#import "ProviderUI.h"
#import <mach-o/getsect.h>

extern const struct mach_header_64 __dso_handle;

// Normal image files in logos/ are linked into the dylib, like the Passkeys resources.
// Google: https://www.gstatic.com/images/branding/googleg/1x/googleg_standard_color_128dp.png
// Anthropic: https://www.anthropic.com/images/icons/safari-pinned-tab.svg
// ChatGPT: the approved white logo from the official Sign in with ChatGPT button assets.
NSImage *DPProviderLogo(NSString *brand) {
    if ([brand isEqual:@"openai"]) brand = @"chatgpt";
    static NSMutableDictionary<NSString *, NSImage *> *images;
    images = images ?: [NSMutableDictionary new];
    NSImage *image = images[brand];
    if (!image) {
        unsigned long size = 0;
        NSString *section = [@"__dp_" stringByAppendingString:brand];
        const void *bytes = getsectiondata(&__dso_handle, "__TEXT", section.UTF8String, &size);
        if (bytes && size) image = [[NSImage alloc] initWithData:[NSData dataWithBytes:bytes length:size]];
        image.template = ![brand isEqual:@"google"];
        if (image) images[brand] = image;
    }
    return image;
}

NSImageView *DPProviderIcon(NSDictionary *provider) {
    NSString *brand = [DPChatProviders brand:provider];
    NSImageView *view;
    if ([brand isEqual:@"apple"] || [brand isEqual:@"custom"]) {
        view = DPSymbol([brand isEqual:@"apple"] ? @"apple.logo" : @"network", 18, NSColor.secondaryLabelColor);
    } else {
        NSImage *image = DPProviderLogo(brand);
        view = image ? [NSImageView imageViewWithImage:image] : DPSymbol(@"network", 18, NSColor.secondaryLabelColor);
        view.contentTintColor = image.isTemplate ? NSColor.labelColor : nil;
    }
    view.imageScaling = NSImageScaleProportionallyUpOrDown;
    [view.widthAnchor constraintEqualToConstant:18].active = YES;
    [view.heightAnchor constraintEqualToConstant:18].active = YES;
    view.accessibilityElement = NO;
    return view;
}
