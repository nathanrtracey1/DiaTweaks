#import "AgentSocket.h"
#import "AgentWriter.h"
#include <sys/socket.h>

static void DPForwardAgent(int source, DPAgentWriter *destination, DPAgentWriter *sender, BOOL requests) {
    const NSUInteger maxLine = 64 * 1024 * 1024;
    NSMutableData *line = [NSMutableData new];
    DPAgentReply reply = ^(NSDictionary *message) {
        NSMutableData *frame = [[NSJSONSerialization dataWithJSONObject:message options:0 error:nil] mutableCopy];
        if (!frame) return;
        [frame appendBytes:"\n" length:1];
        [sender write:frame.bytes length:frame.length];
    };
    char bytes[32768];
    for (;;) @autoreleasepool {
        ssize_t got = read(source, bytes, sizeof bytes);
        if (got < 0 && errno == EINTR) continue;
        if (got <= 0) return;
        NSArray *filters = DPAgentFilters(requests);
        for (const char *part = bytes, *end = bytes + got; part < end;) {
            const char *newline = memchr(part, '\n', end - part);
            size_t length = (newline ?: end) - part;
            if (line.length + length > maxLine) return;
            [line appendBytes:part length:length];
            if (newline) {
                NSData *output = line;
                for (DPAgentFilter filter in filters) {
                    if (!(output = filter(output, reply))) break;
                }
                if (output) {
                    NSMutableData *frame = [output mutableCopy];
                    [frame appendBytes:"\n" length:1];
                    if (![destination write:frame.bytes length:frame.length]) return;
                }
                line.length = 0;
            }
            part = newline ? newline + 1 : end;
        }
    }
}

void DPRelayAgentConnection(int client, int backend) {
    DPAgentWriter *toClient = [[DPAgentWriter alloc] initWithFD:client];
    DPAgentWriter *toAgent = [[DPAgentWriter alloc] initWithFD:backend];
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        DPForwardAgent(backend, toClient, toAgent, NO);
        shutdown(client, SHUT_RDWR);
        shutdown(backend, SHUT_RDWR);
    });
    DPForwardAgent(client, toAgent, toClient, YES);
    shutdown(client, SHUT_RDWR);
    shutdown(backend, SHUT_RDWR);
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    [toClient invalidate];
    [toAgent invalidate];
}
