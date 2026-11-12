#import "Patches/Boosts/Editor.h"

static id DPNext(NSArray *choices, id current) { return choices[([choices indexOfObject:current] + 1) % choices.count]; }

@implementation DPBoostEditor (Look)

- (void)showLook {
    NSDictionary *color = self.boost[@"color"];
    self.pad.color = color;
    self.bulb.image = [NSImage imageWithSystemSymbolName:[color[@"dark"] boolValue] ? @"lightbulb.slash" : @"lightbulb" accessibilityDescription:nil];
    self.noColor.alphaValue = color ? 1 : 0.3;
    self.light.doubleValue = color ? [color[@"light"] doubleValue] : 50;
    DPShowBoostFont(self.fonts, self.boost[@"font"]);
    NSInteger size = [self.boost[@"size"] integerValue];
    self.sizeLabel.stringValue = size == 100 ? @"Size" : [NSString stringWithFormat:@"%ld%%", (long)size];
    self.caseLabel.stringValue = @{ @"uppercase" : @"AA", @"lowercase" : @"aa", @"capitalize" : @"Aa" }[self.boost[@"case"]] ?: @"Case";
}

- (void)look:(NSString *)key is:(id)value {
    self.boost[key] = value;  // nil takes it out.
    [self showLook];
    [self save];
}

// The color so far, or a grey to start from: the pad gives it a hue, the lightbulb alone a plain dark page.
- (NSMutableDictionary *)color {
    return [self.boost[@"color"] ?: @{ @"hue" : @0, @"sat" : @0, @"light" : @50, @"dark" : @NO } mutableCopy];
}

// A drag shows on the page as it goes.
- (void)dragged:(NSDictionary *)color done:(BOOL)done {
    self.boost[@"color"] = color;
    [self showLook];
    if (done) [self save];
    else [self saveIn:0.03 restarting:NO];
}

- (void)pickHue:(double)hue sat:(double)sat done:(BOOL)done {
    NSMutableDictionary *color = self.color;
    color[@"hue"] = @(hue);
    color[@"sat"] = @(sat);
    [self dragged:color done:done];
}

- (void)lightChanged:(NSSlider *)sender {
    NSMutableDictionary *color = self.color;
    color[@"light"] = @(round(sender.doubleValue));
    [self dragged:color done:NO];
}

- (void)toggleDark:(id)sender {
    NSMutableDictionary *color = self.color;
    color[@"dark"] = @(![color[@"dark"] boolValue]);
    [self look:@"color" is:color];
}

- (void)toggleLight:(id)sender {
    self.light.hidden = !self.light.hidden;
    [self fit];
}

- (void)clearColor:(id)sender {
    if (self.boost[@"color"]) [self look:@"color" is:nil];
}

- (void)pickFont:(NSButton *)sender { [self look:@"font" is:[sender.identifier isEqual:self.boost[@"font"]] ? @"" : sender.identifier]; }
- (void)nextSize:(id)sender { [self look:@"size" is:DPNext(DPBoostSizes(), self.boost[@"size"])]; }
- (void)nextCase:(id)sender { [self look:@"case" is:DPNext(DPBoostCases(), self.boost[@"case"])]; }

// Arc's reset: the site's own colors, font, size and case. What's hidden and the code stay.
- (void)resetLook:(id)sender {
    NSDictionary *plain = @{ @"font" : @"", @"size" : @100, @"case" : @"" };
    if (!self.boost[@"color"] && [[self.boost dictionaryWithValuesForKeys:plain.allKeys] isEqual:plain]) return;
    [self.boost removeObjectForKey:@"color"];
    [self.boost addEntriesFromDictionary:plain];
    [self showLook];
    [self save];
}

@end
