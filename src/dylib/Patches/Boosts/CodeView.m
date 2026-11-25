#import "Patches/Boosts/Editor.h"

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

@implementation DPBoostEditor (Code)

// What the Code button opens, in place of the look: Arc opens a window for it. A button at its top goes back.
- (NSView *)makeCodePage {
    NSStackView *heading = [NSStackView stackViewWithViews:@[ DPBoostIconButton(@"chevron.left", @"Back", self, @selector(showLookPage:)), DPBoostTileLabel(@"Code") ]];
    NSTextView *css, *js;
    NSView *cssBox = DPCodeBox(self.boost[@"css"], self, &css), *jsBox = DPCodeBox(self.boost[@"js"], self, &js);
    self.css = css;
    self.js = js;
    NSTextField *jsHint = DPLabel(@"Runs as each page of the site loads. Reload the page to try a change.", 11, NSFontWeightRegular, NSColor.secondaryLabelColor);
    NSStackView *page = [NSStackView new];
    DPFillStack(page, @[ heading, DPHeader(@"CSS"), cssBox, DPHeader(@"JavaScript"), jsBox, jsHint ]);
    [page setCustomSpacing:6 afterView:jsBox];
    return page;
}

@end
