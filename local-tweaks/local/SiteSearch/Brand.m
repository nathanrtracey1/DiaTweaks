#import "SiteSearch.h"

// The site's color: the most common strong hue in its icon, Amazon's orange or Best Buy's blue. Icons with none, such
// as black and white ones, use the accent color.
NSColor *DPBrandColor(NSImage *icon) {
    if (!icon || icon.isTemplate) return NSColor.controlAccentColor;
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:32 pixelsHigh:32 bitsPerSample:8 samplesPerPixel:4
                                                                         hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [icon drawInRect:NSMakeRect(0, 0, 32, 32)];
    [NSGraphicsContext restoreGraphicsState];
    CGFloat weight[12] = {0}, red[12] = {0}, green[12] = {0}, blue[12] = {0};
    for (NSInteger x = 0; x < 32; x++)
        for (NSInteger y = 0; y < 32; y++) {
            NSColor *pixel = [[bitmap colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
            if (pixel.alphaComponent < 0.5 || pixel.saturationComponent < 0.35 || pixel.brightnessComponent < 0.3) continue;
            int bucket = MIN(11, (int)(pixel.hueComponent * 12));
            CGFloat w = pixel.saturationComponent * pixel.brightnessComponent;
            weight[bucket] += w, red[bucket] += pixel.redComponent * w, green[bucket] += pixel.greenComponent * w, blue[bucket] += pixel.blueComponent * w;
        }
    int best = 0;
    for (int i = 1; i < 12; i++) if (weight[i] > weight[best]) best = i;
    if (weight[best] < 3) return NSColor.controlAccentColor;
    return [NSColor colorWithDeviceRed:red[best] / weight[best] green:green[best] / weight[best] blue:blue[best] / weight[best] alpha:1];
}

// Shades of the site's color for light that flows like Siri's: lighter, deeper, and nudged a little warmer and cooler,
// not so far that yellow turns green.
NSColor *DPShade(NSColor *color, CGFloat hue, CGFloat brightness, CGFloat white) {
    NSColor *hsb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    CGFloat h = fmod(hsb.hueComponent + hue + 1, 1);
    NSColor *shade = [NSColor colorWithHue:h saturation:hsb.saturationComponent brightness:MIN(1, hsb.brightnessComponent * brightness) alpha:1];
    return white ? [shade blendedColorWithFraction:white ofColor:NSColor.whiteColor] : shade;
}

// For a site Dia has no icon for yet, a tile of its color with its first letter, drawn here so nothing is fetched.
NSImage *DPLetterIcon(DPSite *site, NSColor *color) {
    NSString *letter = site.name.length ? [site.name substringToIndex:1].uppercaseString : @"?";
    NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    CGFloat light = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent;
    NSColor *ink = light > 0.65 ? [NSColor colorWithWhite:0.1 alpha:1] : NSColor.whiteColor;
    return [NSImage imageWithSize:NSMakeSize(32, 32) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [color setFill];
        [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:7 yRadius:7] fill];
        NSDictionary *style = @{ NSFontAttributeName : [NSFont systemFontOfSize:19 weight:NSFontWeightBold], NSForegroundColorAttributeName : ink };
        NSSize size = [letter sizeWithAttributes:style];
        [letter drawAtPoint:NSMakePoint(NSMidX(rect) - size.width / 2, NSMidY(rect) - size.height / 2) withAttributes:style];
        return YES;
    }];
}
