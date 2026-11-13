#import "Patches/DiaChatModel/Providers.h"
#include <assert.h>

int main(void) { @autoreleasepool {
    NSFileManager *fs = NSFileManager.defaultManager;
    NSString *temporary = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSString *context = NSUUID.UUID.UUIDString;
    NSString *work = [temporary stringByAppendingPathComponent:[NSString stringWithFormat:@"User Data/AgentServer/contexts/%@/work", context]];
    NSString *root = [work stringByAppendingPathComponent:@"artifacts/report"];
    [fs createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *entry = [root stringByAppendingPathComponent:@"index.html"];
    [@"<html><style>body{color:blue}</style><script>document.title='report'</script></html>" writeToFile:entry atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [@"asset" writeToFile:[root stringByAppendingPathComponent:@"asset.css"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSString *canonical = DPAbsoluteChatPath(work, @"/");
    NSDictionary *input = @{ @"site_root": root, @"relative_path": @"index.html" };
    assert(DPReportEntry(input, canonical));
    assert(!DPReportEntry(@{ @"site_root": root, @"relative_path": @"../../secret" }, canonical));
    [fs createSymbolicLinkAtPath:[root stringByAppendingPathComponent:@"outside"] withDestinationPath:@"/etc/hosts" error:nil];
    assert(!DPReportEntry(input, canonical));
    [fs removeItemAtPath:temporary error:nil];
    puts("PASS report assets, active HTML and archive path boundaries");
} }
