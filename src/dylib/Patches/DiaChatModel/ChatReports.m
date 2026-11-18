#import "Providers.h"

NSString *DPReportEntry(NSDictionary *input, NSString *work) {
    NSString *relative = input[@"relative_path"];
    if (![relative isKindOfClass:NSString.class] || relative.isAbsolutePath) return nil;
    NSString *root = DPAbsoluteChatPath(input[@"site_root"], work);
    NSString *artifacts = [work stringByAppendingPathComponent:@"artifacts/"];
    if (![root hasPrefix:artifacts]) return nil;
    NSString *entry = DPAbsoluteChatPath(relative, root);
    if (![entry hasPrefix:[root stringByAppendingString:@"/"]] || !DPPathInsideChat(entry, work, NO)) return nil;
    __block BOOL failed = NO;
    NSDirectoryEnumerator *files = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:root]
        includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey] options:0 errorHandler:^BOOL(NSURL *url, NSError *error) { failed = YES; return NO; }];
    if (!files) return nil;
    for (NSURL *url in files) {
        NSNumber *directory, *symlink;
        if (![url getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil] ||
            ![url getResourceValue:&symlink forKey:NSURLIsSymbolicLinkKey error:nil] || symlink.boolValue) return nil;
        if (!directory.boolValue && !DPPathInsideChat(DPAbsoluteChatPath(url.path, work), work, NO)) return nil;
    }
    return failed ? nil : entry;
}
