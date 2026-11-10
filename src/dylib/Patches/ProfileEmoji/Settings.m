#import "ProfileEmoji.h"

static char DPRowKey;

static NSImage *DPPickerImage(NSString *icon) {
    NSImage *image = [icon hasPrefix:DPSymbolPrefix] ? DPSymbolNamed([icon substringFromIndex:DPSymbolPrefix.length]) : nil;
    return image ?: [NSImage imageWithSystemSymbolName:@"square.dashed" accessibilityDescription:@"Symbol"];
}

@interface DPEmojiField : NSTextField
@end

@implementation DPEmojiField
- (BOOL)becomeFirstResponder {
    BOOL became = [super becomeFirstResponder];
    if (became) dispatch_async(dispatch_get_main_queue(), ^{ [NSApp orderFrontCharacterPalette:self]; });
    return became;
}
@end

// One profile's icon row: an emoji field and a button that picks a symbol instead. Saving either replaces the other.
@interface DPIconRow : NSObject <NSTextFieldDelegate>
@property(copy) NSString *spaceID;
@property(strong) NSTextField *field;
@property(strong) NSButton *button;
@property(strong) NSPopover *popover;
@end

@implementation DPIconRow
- (void)save:(NSString *)icon {
    DPSaveIcon(self.spaceID, icon);
    self.button.image = DPPickerImage(icon);
}

- (void)controlTextDidChange:(NSNotification *)note {
    __block NSString *last = @"";
    [self.field.stringValue enumerateSubstringsInRange:NSMakeRange(0, self.field.stringValue.length) options:NSStringEnumerationByComposedCharacterSequences
                                            usingBlock:^(NSString *character, NSRange _, NSRange __, BOOL *___) { last = character; }];
    last = [last stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![self.field.stringValue isEqual:last]) self.field.stringValue = last;
    [self save:last.length ? last : nil];
}

- (void)showSymbols:(NSButton *)sender {
    NSString *icon = DPSavedIcon(self.spaceID);
    DPSymbolPicker *picker = [DPSymbolPicker new];
    picker.chosen = [icon hasPrefix:DPSymbolPrefix] ? [icon substringFromIndex:DPSymbolPrefix.length] : nil;
    __weak DPIconRow *row = self;
    picker.onPick = ^(NSString *name) {
        row.field.stringValue = @"";
        [row save:name ? [DPSymbolPrefix stringByAppendingString:name] : nil];
        [row.popover close];
    };
    self.popover = [NSPopover new];
    self.popover.behavior = NSPopoverBehaviorTransient;
    self.popover.contentViewController = picker;
    [self.popover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
}
@end

void DPAddEmojiRow(NSViewController *pane) {
    NSView *group = DPFindView(pane.view, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaSettingsFormGroup); });
    NSStackView *rows = (NSStackView *)DPSubview(group, "NSStackView");
    NSTextField *title = (NSTextField *)DPFindView(rows.arrangedSubviews.firstObject, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextField.class]; });
    NSString *spaceID = [DPSwiftValue(pane, @"spaceID") description];
    if (!rows || !title || !spaceID || DPGet(pane, &DPRowKey)) return;

    NSString *icon = DPSavedIcon(spaceID);
    DPIconRow *iconRow = [DPIconRow new];
    iconRow.spaceID = spaceID;
    NSTextField *label = [NSTextField labelWithString:@"Icon"];
    label.font = title.font;
    label.textColor = title.textColor;
    NSTextField *field = iconRow.field = [DPEmojiField textFieldWithString:[icon hasPrefix:DPSymbolPrefix] ? @"" : icon ?: @""];
    field.delegate = iconRow;
    field.alignment = NSTextAlignmentCenter;
    field.bezelStyle = NSTextFieldRoundedBezel;
    field.placeholderString = @"Emoji";
    NSButton *button = iconRow.button = [NSButton buttonWithImage:DPPickerImage(icon) target:iconRow action:@selector(showSymbols:)];
    button.bezelStyle = NSBezelStyleRounded;
    button.toolTip = @"Choose a symbol";
    NSView *row = [NSView new];
    for (NSView *view in @[ label, field, button ]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:view];
    }
    NSBox *line = [NSBox new];
    line.boxType = NSBoxSeparator;
    [rows addArrangedSubview:line];
    [rows addArrangedSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:42], [row.widthAnchor constraintEqualToAnchor:rows.widthAnchor],
        [line.widthAnchor constraintEqualToAnchor:rows.widthAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [field.trailingAnchor constraintEqualToAnchor:row.trailingAnchor], [field.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [field.widthAnchor constraintEqualToConstant:64],
        [button.trailingAnchor constraintEqualToAnchor:field.leadingAnchor constant:-8], [button.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    DPSet(pane, &DPRowKey, iconRow);
}
