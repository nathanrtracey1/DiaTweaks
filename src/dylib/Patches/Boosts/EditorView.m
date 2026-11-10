#import "Patches/Boosts/Editor.h"

static const CGFloat DPEditorWidth = 340, DPEditorInset = 14;

// Monospaced, on the same ground as Settings' groups.
static NSView *DPCodeBox(NSString *text, id<NSTextViewDelegate> delegate, NSTextView **editor) {
    NSScrollView *scroll = [NSTextView scrollableTextView];
    NSTextView *code = scroll.documentView;
    code.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    code.textColor = NSColor.labelColor;
    code.richText = NO;
    code.allowsUndo = YES;
    code.usesFindBar = YES;
    code.automaticQuoteSubstitutionEnabled = code.automaticDashSubstitutionEnabled = code.automaticTextReplacementEnabled = NO;
    code.automaticSpellingCorrectionEnabled = code.continuousSpellCheckingEnabled = code.automaticLinkDetectionEnabled = NO;
    code.textContainerInset = NSMakeSize(6, 8);
    code.drawsBackground = scroll.drawsBackground = NO;
    code.string = text;
    code.delegate = delegate;
    DPFillView *box = [DPFillView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [box addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:box.leadingAnchor], [scroll.trailingAnchor constraintEqualToAnchor:box.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:box.topAnchor], [scroll.bottomAnchor constraintEqualToAnchor:box.bottomAnchor],
        [box.heightAnchor constraintEqualToConstant:110],
    ]];
    *editor = code;
    return box;
}

// "Site’s Own" first, then every family. A saved font that's no longer installed stays listed, so it isn't lost.
static NSPopUpButton *DPFontPicker(NSString *font) {
    NSPopUpButton *picker = [NSPopUpButton new];
    picker.controlSize = NSControlSizeSmall;
    picker.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
    [picker addItemWithTitle:@"Site’s Own"];
    picker.lastItem.representedObject = @"";
    [picker.menu addItem:NSMenuItem.separatorItem];
    NSArray *families = NSFontManager.sharedFontManager.availableFontFamilies;
    for (NSString *family in [families containsObject:font] || !font.length ? families : [@[ font ] arrayByAddingObjectsFromArray:families]) {
        [picker addItemWithTitle:family];
        picker.lastItem.representedObject = family;
    }
    [picker selectItemAtIndex:MAX(0, [picker indexOfItemWithRepresentedObject:font])];
    return picker;
}

@implementation DPBoostEditor (Layout)

- (NSView *)makeContent:(NSDictionary *)boost {
    self.enabled = [NSSwitch new];
    self.enabled.state = [boost[@"enabled"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    self.enabled.target = self;
    self.enabled.action = @selector(changed:);
    NSTextField *site = DPBoostLabel(@"");
    site.attributedStringValue = DPBoostTitle(DPBoostSiteName(self.domain), self.domain, NSFontWeightSemibold);
    NSString *domain = self.domain;
    if ([DPFrontDomain() isEqual:domain])
        DPPageSiteName(DPFrontContents(), ^(NSString *name) { site.attributedStringValue = DPBoostTitle(name, domain, NSFontWeightSemibold); });
    NSStackView *heading = [NSStackView stackViewWithViews:@[ DPBoostFavicon(self.domain, 16), site ]];

    NSView *hidden = [self makeZapGroup];
    self.font = DPFontPicker(boost[@"font"]);
    self.font.target = self;
    self.font.action = @selector(changed:);

    NSTextView *css, *js;
    NSView *cssBox = DPCodeBox(boost[@"css"], self, &css), *jsBox = DPCodeBox(boost[@"js"], self, &js);
    self.css = css;
    self.js = js;
    NSTextField *jsHint = DPLabel(@"Runs as each page of the site loads. Reload the page to try a change.", 11, NSFontWeightRegular, NSColor.secondaryLabelColor);

    NSPopUpButton *more = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:YES];
    more.controlSize = NSControlSizeSmall;
    more.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
    [more addItemWithTitle:@"Options"];
    [more.menu addItemWithTitle:@"Import Boost File…" action:@selector(importBoost:) keyEquivalent:@""].target = self;
    [more.menu addItemWithTitle:@"Export Boost File…" action:@selector(exportBoost:) keyEquivalent:@""].target = self;
    [more.menu addItem:NSMenuItem.separatorItem];
    [more.menu addItemWithTitle:@"Delete Boost…" action:@selector(deleteBoost:) keyEquivalent:@""].target = self;
    NSStackView *footer = [NSStackView new];
    [footer addView:more inGravity:NSStackViewGravityTrailing];

    NSStackView *content = [NSStackView new];
    DPFillStack(content, @[
        DPGroup(@[ DPRow(heading, self.enabled) ]), DPHeader(@"Hidden"), hidden,
        DPGroup(@[ DPRow(DPLabel(@"Font", 13, NSFontWeightRegular, NSColor.labelColor), self.font) ]),
        DPHeader(@"CSS"), cssBox, DPHeader(@"JavaScript"), jsBox, jsHint, footer,
    ]);
    [content setCustomSpacing:6 afterView:jsBox];
    NSView *root = [DPFlippedView new];  // Growing, it keeps what's in it where it was from the top, not the bottom, until laid out.
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:DPEditorInset],
        [content.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-DPEditorInset],
        [content.topAnchor constraintEqualToAnchor:root.topAnchor constant:DPEditorInset],
        // The Options button draws its bezel a couple of points inside its frame, so it looks as far from the bottom as from the side.
        [content.bottomAnchor constraintLessThanOrEqualToAnchor:root.bottomAnchor constant:-(DPEditorInset - 2)],  // Stays put while the popover resizes.
        [root.widthAnchor constraintEqualToConstant:DPEditorWidth],
    ]];
    return root;
}

@end
