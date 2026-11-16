#import "Patches/DiaChatModel/Providers.h"
#include <assert.h>

int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Model"];
    [menu addItemWithTitle:@"Dia Default" action:nil keyEquivalent:@""].representedObject = @"dia-default";
    DPAppendProviderModels(menu, @[
        @{ @"id": @"local", @"name": @"Apple Intelligence", @"catalog": @[@{ @"id": @"on-device", @"name": @"Apple Intelligence" }],
           @"visibility": @{ @"on-device": @YES } },
        @{ @"id": @"first", @"name": @"Remote", @"catalog": @[@{ @"id": @"same-id", @"name": @"Model" }],
           @"visibility": @{ @"same-id": @YES } },
        @{ @"id": @"second", @"name": @"Other", @"catalog": @[@{ @"id": @"same-id", @"name": @"Model" }],
           @"visibility": @{ @"same-id": @YES } },
        @{ @"id": @"hidden", @"name": @"Hidden", @"catalog": @[@{ @"id": @"off", @"name": @"Off" }],
           @"visibility": @{ @"off": @NO } }]);
    NSPopUpButton *picker = [NSPopUpButton new]; picker.menu = menu;
    [menu update];
    NSUInteger apple = 0, headings = 0;
    NSMutableSet *choices = [NSMutableSet new];
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.title isEqual:@"Apple Intelligence"]) apple++;
        assert(![item.title isEqual:@"Hidden"]);
        if (item.isSeparatorItem) continue;
        if (item.isSectionHeader) { assert(!item.enabled && !item.representedObject); headings++; continue; }
        assert(item.enabled && [item.representedObject isKindOfClass:NSString.class]);
        [choices addObject:item.representedObject];
    }
    assert(apple == 1 && headings == 2 && choices.count == 4);
    [picker selectItemWithTitle:@"Apple Intelligence"];
    assert([picker.selectedItem.representedObject isEqual:@"provider:local/on-device"]);
    assert([choices containsObject:@"provider:first/same-id"] && [choices containsObject:@"provider:second/same-id"]);
    puts("PASS provider menu headings, single-model labels and account-qualified selections");
} }
