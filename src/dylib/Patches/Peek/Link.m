#import "Patches/Peek/Peek.h"

// The status text shows an address as people read it (accents, spaces, an international host in Unicode); a click's URL has them escaped.
// Escape the text the same way by hand: NSURL escapes a string that already holds escapes differently from one macOS to the next. Only the host goes through it.
NSString *DPPeekLinkKey(NSString *address) {
    static NSCharacterSet *legal;
    if (!legal) legal = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#@!$&'()*+,;=%"];
    for (NSString *scheme in @[ @"https://", @"http://" ])
        if ([address hasPrefix:scheme]) address = [address substringFromIndex:scheme.length];
    NSUInteger end = [address rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#"]].location;
    if (end == NSNotFound) end = address.length;
    NSString *host = [address substringToIndex:end], *rest = [address substringFromIndex:end];
    if (![host canBeConvertedToEncoding:NSASCIIStringEncoding])
        host = [[NSURL URLWithString:[@"http://" stringByAppendingString:host]].absoluteString substringFromIndex:@"http://".length] ?: host;
    rest = [rest stringByReplacingOccurrencesOfString:@"%(?![0-9A-Fa-f]{2})" withString:@"%25" options:NSRegularExpressionSearch range:NSMakeRange(0, rest.length)];
    NSRange hash = [rest rangeOfString:@"#"];
    if (hash.length) rest = [[rest substringToIndex:NSMaxRange(hash)] stringByAppendingString:[[rest substringFromIndex:NSMaxRange(hash)] stringByReplacingOccurrencesOfString:@"#" withString:@"%23"]];
    address = [host stringByAppendingString:[rest stringByAddingPercentEncodingWithAllowedCharacters:legal] ?: rest];
    return [address hasSuffix:@"/"] ? [address substringToIndex:address.length - 1] : address;
}
