#import <Foundation/Foundation.h>

NSString *DPChatAttachmentContent(NSData *data) {
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) return nil;
    id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![value isKindOfClass:NSDictionary.class]) return text;
    NSDictionary *video = [value[@"videoContent"] isKindOfClass:NSDictionary.class] ? value[@"videoContent"] : nil;
    if (video) {
        NSDictionary *details = [video[@"details"] isKindOfClass:NSDictionary.class] ? video[@"details"] : @{};
        NSDictionary *transcript = [video[@"transcript"] isKindOfClass:NSDictionary.class] ? video[@"transcript"] : @{};
        NSMutableArray *parts = [NSMutableArray new];
        for (NSString *key in @[@"title", @"author"])
            if ([details[key] isKindOfClass:NSString.class]) [parts addObject:[NSString stringWithFormat:@"%@: %@", key, details[key]]];
        if ([transcript[@"hasTranscript"] isEqual:@YES] && [transcript[@"data"] isKindOfClass:NSString.class] && [transcript[@"data"] length])
            [parts addObject:[@"Video transcript:\n" stringByAppendingString:transcript[@"data"]]];
        else {
            [parts addObject:@"No video transcript was supplied. Only the following page metadata is available; it does not establish everything said or shown in the video."];
            if ([details[@"description"] isKindOfClass:NSString.class]) [parts addObject:details[@"description"]];
        }
        return [parts componentsJoinedByString:@"\n\n"];
    }
    return [value[@"webpageMarkdown"] isKindOfClass:NSString.class] ? value[@"webpageMarkdown"] : text;
}
