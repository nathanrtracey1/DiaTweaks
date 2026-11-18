#import "Providers.h"

void DPAppendProviderModels(NSMenu *menu, NSArray<NSDictionary *> *accounts) {
    // A pop-up button can re-enable ordinary title items while validating its menu.
    menu.autoenablesItems = NO;
    for (NSDictionary *account in accounts) {
        NSArray *models = [account[@"catalog"] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
            return [account[@"visibility"][item[@"id"]] boolValue];
        }]];
        if (!models.count) continue;
        [menu addItem:NSMenuItem.separatorItem];
        if (models.count != 1 || ![models.firstObject[@"name"] isEqual:account[@"name"]]) {
            NSMenuItem *heading = [NSMenuItem sectionHeaderWithTitle:account[@"name"]];
            heading.enabled = NO; [menu addItem:heading];
        }
        for (NSDictionary *model in models) {
            NSString *choice = [NSString stringWithFormat:@"provider:%@/%@", account[@"id"], model[@"id"]];
            [menu addItemWithTitle:model[@"name"] action:nil keyEquivalent:@""].representedObject = choice;
        }
    }
}
