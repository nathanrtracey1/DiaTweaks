#import "AgentSocket.h"
#import "AgentRelay.h"
#include <poll.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/stat.h>

static void DPConfigureAgentSocket(int fd) {
    struct timeval timeout = { .tv_sec = 15 };
    fcntl(fd, F_SETFD, FD_CLOEXEC);
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &(int){1}, sizeof(int));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof timeout);
}

int DPAgentSocket(void) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd >= 0) DPConfigureAgentSocket(fd);
    return fd;
}

struct sockaddr_un DPAgentAddress(const char *path) {
    struct sockaddr_un address = { .sun_family = AF_UNIX };
    strlcpy(address.sun_path, path, sizeof address.sun_path);
    address.sun_len = SUN_LEN(&address);
    return address;
}

static BOOL DPPeer(int fd, pid_t expected) {
    uid_t uid;
    gid_t gid;
    pid_t pid;
    socklen_t size = sizeof pid;
    return !getpeereid(fd, &uid, &gid) && uid == getuid() &&
        !getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &pid, &size) && pid == expected;
}

static int DPConnectAgent(NSString *path, pid_t child) {
    struct sockaddr_un address = DPAgentAddress(path.fileSystemRepresentation);
    for (int attempt = 0; attempt < 200 && !kill(child, 0); attempt++) {
        int fd = DPAgentSocket();
        if (fd < 0) break;
        if (!connect(fd, (struct sockaddr *)&address, address.sun_len) && DPPeer(fd, child)) return fd;
        close(fd);
        usleep(25000);
    }
    return -1;
}

void DPRelayChatAgent(int listener, NSString *socket, NSString *directory, pid_t child, DPAgentConnected connected) {
    struct stat identity = {0};
    lstat(socket.fileSystemRepresentation, &identity);
    NSString *path = [directory stringByAppendingPathComponent:@"agent.sock"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        struct pollfd event = { .fd = listener, .events = POLLIN };
        while (!kill(child, 0)) {
            int ready = poll(&event, 1, 500);
            if (ready < 0 && errno == EINTR) continue;
            if (ready < 0 || (event.revents & (POLLERR | POLLHUP | POLLNVAL))) break;
            if (!(event.revents & POLLIN)) continue;
            int client = accept(listener, NULL, NULL);
            if (client < 0) continue;
            DPConfigureAgentSocket(client);
            if (DPPeer(client, getpid())) {
                int backend = DPConnectAgent(path, child);
                if (backend >= 0) {
                    if (connected) connected(directory);
                    DPRelayAgentConnection(client, backend);
                    close(backend);
                }
            }
            close(client);
        }
        struct stat current;
        if (!lstat(socket.fileSystemRepresentation, &current) &&
            current.st_dev == identity.st_dev && current.st_ino == identity.st_ino)
            unlink(socket.fileSystemRepresentation);
        close(listener);
        unlink(path.fileSystemRepresentation);
        rmdir(directory.fileSystemRepresentation);
    });
}
