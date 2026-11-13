#import "Providers.h"
#include <sys/stat.h>

static NSString *DPCanonicalChatPath(NSString *path) {
    NSString *normalized = path.stringByStandardizingPath;
    // Foundation may leave /private on a path whose final component does not exist yet.
    if ([normalized hasPrefix:@"/private/var/"] || [normalized hasPrefix:@"/private/tmp/"])
        return [normalized substringFromIndex:[@"/private" length]];
    return normalized;
}

NSString *DPAbsoluteChatPath(id value, NSString *directory) {
    if (![value isKindOfClass:NSString.class] || [value length] > PATH_MAX || [value containsString:[NSString stringWithFormat:@"%C", (unichar)0]]) return nil;
    NSString *name = value;
    return DPCanonicalChatPath(name.isAbsolutePath ? name : [directory stringByAppendingPathComponent:name]);
}

NSString *DPChatWorkDirectory(NSDictionary *body, NSString *context) {
    if (![[NSUUID alloc] initWithUUIDString:context]) return nil;
    NSRegularExpression *tag = [NSRegularExpression regularExpressionWithPattern:
        @"<agent-context>\\s*<agent-id>[^<]+</agent-id>\\s*<working-directory>([^<]+)</working-directory>" options:0 error:nil];
    for (NSDictionary *message in [body[@"messages"] reverseObjectEnumerator]) {
        if (![message[@"role"] isEqual:@"user"]) continue;
        id value = message[@"content"];
        NSArray *parts = [value isKindOfClass:NSString.class] ? @[ @{ @"text": value } ] : value;
        if (![parts isKindOfClass:NSArray.class] || !parts.count) continue;
        for (id part in parts) {
            NSString *text = [part isKindOfClass:NSDictionary.class] ? part[@"text"] : nil;
            if (![text isKindOfClass:NSString.class]) continue;
            NSTextCheckingResult *match = [tag firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
            if (!match) continue;
            NSString *directory = DPCanonicalChatPath([text substringWithRange:[match rangeAtIndex:1]]);
            NSString *ending = [NSString stringWithFormat:@"/AgentServer/contexts/%@/work", context];
            BOOL matches = directory.isAbsolutePath && [directory containsString:@"/User Data/"] &&
                [directory.lowercaseString hasSuffix:ending.lowercaseString];
            return matches ? directory : nil;
        }
    }
    return nil;
}

BOOL DPPathInsideChat(NSString *file, NSString *work, BOOL mayCreate) {
    if (!file || !work || ![file hasPrefix:[work stringByAppendingString:@"/"]]) return NO;
    NSString *root = DPCanonicalChatPath(work.stringByResolvingSymlinksInPath);
    if (![root isEqual:work]) return NO;
    struct stat st;
    for (NSString *path = file; ![path isEqual:work]; path = path.stringByDeletingLastPathComponent) {
        if (lstat(path.fileSystemRepresentation, &st)) {
            if (!mayCreate || errno != ENOENT) return NO;
            continue;
        }
        if ([path isEqual:file] ? !S_ISREG(st.st_mode) || st.st_nlink != 1 : !S_ISDIR(st.st_mode)) return NO;
    }
    return YES;
}
