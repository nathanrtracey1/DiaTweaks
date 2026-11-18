#import "ProviderUI.h"

void DPGroupChatModelOptions(NSStackView *page, NSView *model, NSView *fallback, NSView *safety) {
    NSStackView *group = [model.superview isKindOfClass:NSStackView.class] ? (id)model.superview : nil;
    if (!group || fallback.superview != group || safety.superview != group) return;
    NSView *status = DPFindView(group, ^BOOL(NSView *view) { return DPIsKind(view, "DPChatModelStatusRow"); }).superview;
    NSView *box = group.superview;
    if (!status || status.superview != group || box.superview != page) return;
    NSUInteger index = [page.arrangedSubviews indexOfObject:box];
    if (index == NSNotFound || !index) return;
    NSTextField *heading = (id)page.arrangedSubviews[index - 1];
    if (![heading isKindOfClass:NSTextField.class]) return;

    for (NSView *row in @[model, status, fallback, safety]) {
        [group removeArrangedSubview:row];
        [row removeFromSuperview];
    }
    [page removeArrangedSubview:box];
    [box removeFromSuperview];
    heading.stringValue = @"Model";
    NSArray<NSView *> *sections = @[DPGroup(@[model, status]), DPHeader(@"Behavior"), DPGroup(@[fallback, safety])];
    for (NSUInteger i = 0; i < sections.count; i++) {
        NSView *view = sections[i];
        [page insertArrangedSubview:view atIndex:index + i];
        [view.widthAnchor constraintEqualToAnchor:page.widthAnchor].active = YES;
        if ([view isKindOfClass:DPFillView.class]) [page setCustomSpacing:20 afterView:view];
    }
}
