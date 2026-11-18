#import "StdPatch/Hook.m"
#import <pthread.h>
#import <stdatomic.h>

@interface DPTarget : NSObject
- (int)work;
@end
@implementation DPTarget
- (int)work { return 1; }
@end

static int DPTarget_work(id self, SEL _cmd) { return DPCallOriginal(DPTarget_work, self) + 1; }
static int DPSub_work(id self, SEL _cmd) { return DPCallOriginal(DPSub_work, self) + 1; }

static atomic_bool stop;
static atomic_long calls, wrong;
static DPTarget *target;

// Walks the hook table the way every hooked method does, while the main thread keeps adding hooks.
static void *reader(void *unused) {
    while (!atomic_load(&stop)) {
        if ([target work] != 2) atomic_fetch_add(&wrong, 1);
        atomic_fetch_add(&calls, 1);
    }
    return NULL;
}

static Class subclass(int index) {
    Class cls = objc_allocateClassPair(NSObject.class, [NSString stringWithFormat:@"DPHookTableSub%d", index].UTF8String, 0);
    class_addMethod(cls, @selector(work), imp_implementationWithBlock(^int(id self) { return 1; }), "i@:");
    objc_registerClassPair(cls);
    return cls;
}

int main(void) {
    int failures = 0;
    @autoreleasepool {
        target = [DPTarget new];
        DPHookClass(DPTarget.class, @selector(work), (IMP)DPTarget_work);
        pthread_t threads[4];
        for (int i = 0; i < 4; i++) pthread_create(&threads[i], NULL, reader, NULL);
        while (!atomic_load(&calls)) usleep(100);

        id first = nil, last = nil;
        int hooked = 0;
        for (; hooked < 4000; hooked++) {
            last = [subclass(hooked) new];
            DPHookClass(object_getClass(last), @selector(work), (IMP)DPSub_work);
            if ([last work] != 2) break;
            first = first ?: last;
            if (DPOriginalIMP(last, @selector(work), (IMP)DPSub_work) == (IMP)DPSub_work) { failures++; printf("FAIL the original of a new hook is its replacement\n"); }
        }
        atomic_store(&stop, YES);
        for (int i = 0; i < 4; i++) pthread_join(threads[i], NULL);

        if (atomic_load(&wrong)) { failures++; printf("FAIL %ld of %ld calls on other threads missed their hook\n", atomic_load(&wrong), atomic_load(&calls)); }
        if (hooked < 500 || hooked >= 4000) { failures++; printf("FAIL the table took %d hooks, expected it to fill up in between\n", hooked); }
        if ([last work] != 1) { failures++; printf("FAIL a hook past the end of the table took effect\n"); }
        if ([target work] != 2 || [first work] != 2) { failures++; printf("FAIL the full table broke earlier hooks\n"); }
        printf("%d hooks, %ld calls from 4 threads while they were added\n", hooked + 1, atomic_load(&calls));
    }
    if (!failures) printf("all hook table checks passed\n");
    return failures ? 1 : 0;
}
