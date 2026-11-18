#import <dlfcn.h>
#import <objc/runtime.h>
#import <unistd.h>
#import "StdPatch/StdPatch.h"

// The launch guard keeps its state beside the dylib: point it at a temporary folder.
static const char *DPTestDylib;
static int DPTestDladdr(const void *address, Dl_info *info) {
    int found = dladdr(address, info);
    info->dli_fname = DPTestDylib;
    return found;
}
#define dladdr DPTestDladdr

static void (^DPQuit)(void);
void DPOnQuit(void (^block)(void)) { DPQuit = [block copy]; }

#import "SafeMode/SafeMode.m"

// A launch is a child process, so each has its own pid like Dia's: it reports "level" once started, then obeys "quit" or "crash".
static void child(const char *support, const char *home) {
    @autoreleasepool {
        NSURL *reports = [NSURL fileURLWithPath:@(home)];
        class_replaceMethod(NSFileManager.class, @selector(homeDirectoryForCurrentUser), imp_implementationWithBlock(^NSURL *(id self) { return reports; }), "@@:");
        DPTestDylib = [[@(support) stringByAppendingPathComponent:@"DiaPatches.dylib"] fileSystemRepresentation];
        DPBeginLaunch();
        printf("level %ld\n", (long)DPSafeMode);
        fflush(stdout);
        char command[16] = "";
        if (fgets(command, sizeof command, stdin) && !strncmp(command, "quit", 4)) DPQuit();
        printf("done\n");
        fflush(stdout);
        _exit(0);
    }
}

@interface DPLaunch : NSObject
@property NSTask *task;
@property NSFileHandle *input, *output;
@property NSInteger level;
@end
@implementation DPLaunch
- (NSString *)line {
    NSMutableData *line = [NSMutableData data];
    for (NSData *byte = [self.output readDataOfLength:1]; byte.length && *(const char *)byte.bytes != '\n'; byte = [self.output readDataOfLength:1]) [line appendData:byte];
    return [[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding];
}
- (void)end:(NSString *)command {
    [self.input writeData:[[command stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [self line];
    [self.task waitUntilExit];
}
@end

static NSString *support, *home;
static int failures;

static DPLaunch *launch(void) {
    DPLaunch *launch = [DPLaunch new];
    NSPipe *in = [NSPipe pipe], *out = [NSPipe pipe];
    launch.task = [NSTask new];
    launch.task.executableURL = [NSURL fileURLWithPath:NSBundle.mainBundle.executablePath];
    launch.task.arguments = @[ @"child", support, home ];
    launch.task.standardInput = in;
    launch.task.standardOutput = out;
    launch.input = in.fileHandleForWriting;
    launch.output = out.fileHandleForReading;
    [launch.task launchAndReturnError:nil];
    launch.level = [[[launch line] substringFromIndex:6] integerValue];
    return launch;
}

static NSDictionary *state(void) { return [NSDictionary dictionaryWithContentsOfFile:[support stringByAppendingPathComponent:@"safe-mode.plist"]]; }

static void expect(BOOL ok, NSString *what) {
    if (ok) return;
    failures++;
    printf("FAIL %s\n", what.UTF8String);
}

// Dia crashed while launching: macOS leaves a report that names its pid.
static void leaveCrashed(DPLaunch *launch) {
    [launch end:@"crash"];
    NSString *folder = [home stringByAppendingPathComponent:@"Library/Logs/DiagnosticReports"];
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *report = [NSString stringWithFormat:@"%@-%d.ips", NSProcessInfo.processInfo.processName, launch.task.processIdentifier];
    [[NSString stringWithFormat:@"{\n  \"pid\" : %d,\n}\n", launch.task.processIdentifier] writeToFile:[folder stringByAppendingPathComponent:report] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

int main(int argc, const char *argv[]) {
    if (argc == 4 && !strcmp(argv[1], "child")) child(argv[2], argv[3]);
    @autoreleasepool {
        NSString *temporary = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
        support = [temporary stringByAppendingPathComponent:@"support"];
        home = [temporary stringByAppendingPathComponent:@"home"];
        [NSFileManager.defaultManager createDirectoryAtPath:support withIntermediateDirectories:YES attributes:nil error:nil];

        DPLaunch *first = launch();
        expect([state()[@"launching"] boolValue] && [state()[@"pid"] intValue] == first.task.processIdentifier, @"a launch marks the file with its pid");
        [first end:@"quit"];
        expect(![state()[@"launching"] boolValue], @"a launch that quits clears the marker");

        // Chromium relaunches Dia: the new process starts before the old one exits, and then crashes while launching.
        DPLaunch *old = launch(), *relaunched = launch();
        [old end:@"quit"];
        expect([state()[@"launching"] boolValue] && [state()[@"pid"] intValue] == relaunched.task.processIdentifier, @"the old process leaves the new process's marker alone");
        leaveCrashed(relaunched);
        DPLaunch *next = launch(), *again = launch();
        expect([state()[@"crashes"] integerValue] == 1, @"the crash of the relaunched Dia is counted");
        [next end:@"quit"];
        leaveCrashed(again);
        DPLaunch *last = launch();
        expect(last.level == 1, @"two crashes of relaunched Dias turn safe mode on");
        [last end:@"quit"];

        [NSFileManager.defaultManager removeItemAtPath:temporary error:nil];
    }
    if (!failures) printf("all launch guard checks passed\n");
    return failures ? 1 : 0;
}
