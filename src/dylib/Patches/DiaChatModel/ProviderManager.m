#import "ProviderUI.h"

NSStackView *DPProviderColumn(NSArray<NSView *> *views) {
    NSStackView *stack = [NSStackView stackViewWithViews:views];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading; stack.spacing = 10;
    return stack;
}

@implementation DPProviderManager
+ (void)show {
    static DPProviderManager *controller;
    if (controller.window.sheetParent || controller.window.visible) { [controller.window makeKeyAndOrderFront:nil]; return; }
    controller = [DPProviderManager new];
    [controller prepare];
    NSWindow *parent = NSApp.keyWindow ?: NSApp.mainWindow;
    if (parent && !parent.attachedSheet) [parent beginSheet:controller.window completionHandler:nil];
    else [controller showWindow:nil];
    for (NSDictionary *provider in DPChatProviders.accounts)
        [DPChatProviders refresh:provider[@"id"] force:NO completion:^(NSString *error) { [controller reload]; }];
}
- (void)prepare {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 650, 480)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Model Providers";
    self.accounts = [NSPopUpButton new]; self.accounts.target = self; self.accounts.action = @selector(select:);
    NSStackView *toolbar = [NSStackView stackViewWithViews:@[self.accounts,
        [NSButton buttonWithTitle:@"Add…" target:self action:@selector(add:)],
        [NSButton buttonWithTitle:@"Edit…" target:self action:@selector(edit:)],
        [NSButton buttonWithTitle:@"Remove" target:self action:@selector(remove:)]]];
    self.models = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 600, 300)];
    for (NSString *name in @[@"Show", @"Model", @"ID"]) {
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:name];
        column.title = name; column.width = [name isEqual:@"Show"] ? 50 : 265;
        [self.models addTableColumn:column];
    }
    self.models.delegate = self; self.models.dataSource = self;
    NSScrollView *scroll = [NSScrollView new]; scroll.documentView = self.models; scroll.hasVerticalScroller = YES;
    [scroll.heightAnchor constraintEqualToConstant:280].active = YES;
    self.future = [NSButton checkboxWithTitle:@"Add future models automatically" target:self action:@selector(future:)];
    NSStackView *actions = [NSStackView stackViewWithViews:@[
        [NSButton buttonWithTitle:@"Select All" target:self action:@selector(all:)],
        [NSButton buttonWithTitle:@"Deselect All" target:self action:@selector(none:)],
        [NSButton buttonWithTitle:@"Refresh Models" target:self action:@selector(refresh:)],
        [NSButton buttonWithTitle:@"Add Model ID…" target:self action:@selector(manual:)]]];
    self.status = [NSTextField wrappingLabelWithString:@""];
    NSButton *done = [NSButton buttonWithTitle:@"Done" target:self action:@selector(done:)];
    NSStackView *content = DPProviderColumn(@[toolbar, scroll, self.future, actions, self.status, done]);
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.window.contentView addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor constant:20],
        [content.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor constant:-20],
        [content.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor constant:20],
        [scroll.widthAnchor constraintEqualToAnchor:content.widthAnchor]]];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:@"DPChatProvidersChanged" object:nil];
    [self reload];
}
- (void)done:(id)sender {
    if (self.window.sheetParent) [self.window.sheetParent endSheet:self.window];
    [self.window orderOut:nil];
}
- (void)problem:(NSString *)message { self.status.stringValue = message ?: @""; }
- (void)select:(id)sender { self.identifier = self.accounts.selectedItem.representedObject; [self reload]; }
- (void)reload {
    NSString *selected = self.identifier;
    [self.accounts removeAllItems];
    for (NSDictionary *provider in DPChatProviders.accounts) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:provider[@"name"] action:nil keyEquivalent:@""];
        item.representedObject = provider[@"id"]; [self.accounts.menu addItem:item];
        if ([item.representedObject isEqual:selected]) [self.accounts selectItem:item];
    }
    self.identifier = self.accounts.selectedItem.representedObject;
    NSDictionary *account = [DPChatProviders account:self.identifier ?: @""];
    self.future.state = [account[@"autoAdd"] boolValue]; self.future.enabled = account != nil;
    self.status.stringValue = [DPChatProviders status:self.identifier ?: @""] ?: @"";
    [self.models reloadData];
}
@end
