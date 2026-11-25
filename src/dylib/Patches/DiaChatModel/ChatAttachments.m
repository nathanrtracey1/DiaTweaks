#import "Providers.h"
NSString *DPChatAttachmentContent(NSData *data);

static NSString *DPAttachmentAttribute(NSString *tag, NSString *name) {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\\b%@=\"([^\"]*)\"", name] options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:tag options:0 range:NSMakeRange(0, tag.length)];
    return match ? [tag substringWithRange:[match rangeAtIndex:1]] : nil;
}

static NSString *DPAttachmentText(NSString *tag, NSString *root, NSUInteger *remaining) {
    NSString *path = DPAttachmentAttribute(tag, @"path"), *parts = DPAttachmentAttribute(tag, @"parts");
    if (!path.length || path.isAbsolutePath || [path.pathComponents containsObject:@".."] || [path containsString:@":"] || [path containsString:@"\\"]) return nil;
    NSInteger count = parts ? parts.integerValue : 1;
    if (count < 1 || count > 64 || (parts && ![parts isEqual:@(count).stringValue])) return nil;
    NSMutableData *contents = [NSMutableData new];
    for (NSInteger index = 1; index <= count; index++) {
        NSString *name = parts ? [path stringByAppendingPathComponent:@(index).stringValue] : path;
        NSString *file = DPAbsoluteChatPath(name, root);
        if (!DPPathInsideChat(file, root, NO)) return nil;
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:file error:nil];
        NSUInteger size = [attributes[NSFileSize] unsignedIntegerValue];
        if (size > 512 * 1024 || size > *remaining) return nil;
        NSData *data = [NSData dataWithContentsOfFile:file options:0 error:nil];
        if (!data || data.length > *remaining) return nil;
        *remaining -= data.length; [contents appendData:data];
    }
    NSString *text = DPChatAttachmentContent(contents);
    if (!text) return nil;
    // Source text must not close the adapter's attachment framing or impersonate the user's query.
    text = [text stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    return [NSString stringWithFormat:@"<attachment type=\"%@\" src=\"%@\">%@</attachment>",
        DPAttachmentAttribute(tag, @"type") ?: @"file", DPAttachmentAttribute(tag, @"src") ?: @"", text];
}

static NSString *DPExpandChatText(NSString *text, NSString *root, NSUInteger *remaining) {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<attachment\\b[^>]*\\bpath=\"[^\"]+\"[^>]*/\\s*>" options:0 error:nil];
    NSMutableString *result = [text mutableCopy];
    for (NSTextCheckingResult *match in [[regex matchesInString:text options:0 range:NSMakeRange(0, text.length)] reverseObjectEnumerator]) {
        NSString *expanded = DPAttachmentText([text substringWithRange:match.range], root, remaining);
        if (expanded) [result replaceCharactersInRange:match.range withString:expanded];
    }
    return result;
}

NSDictionary *DPInlineChatAttachments(NSDictionary *body, NSString *context) {
    NSString *work = DPChatWorkDirectory(body, context);
    if (!work.length) return body;
    NSString *root = [work.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"attachments"];
    NSMutableDictionary *result = [body mutableCopy]; NSMutableArray *messages = [NSMutableArray new];
    NSUInteger remaining = 4 * 1024 * 1024;
    for (NSDictionary *message in body[@"messages"]) {
        NSMutableDictionary *copy = [message mutableCopy]; id content = message[@"content"];
        if ([message[@"role"] isEqual:@"user"] && [content isKindOfClass:NSString.class]) copy[@"content"] = DPExpandChatText(content, root, &remaining);
        else if ([message[@"role"] isEqual:@"user"] && [content isKindOfClass:NSArray.class]) {
            NSMutableArray *blocks = [NSMutableArray new];
            for (NSDictionary *block in content) {
                NSMutableDictionary *part = [block mutableCopy];
                if ([part[@"type"] isEqual:@"text"] && [part[@"text"] isKindOfClass:NSString.class]) part[@"text"] = DPExpandChatText(part[@"text"], root, &remaining);
                [blocks addObject:part];
            }
            copy[@"content"] = blocks;
        }
        [messages addObject:copy];
    }
    result[@"messages"] = messages; return result;
}
