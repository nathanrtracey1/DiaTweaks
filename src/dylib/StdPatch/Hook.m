#import "StdPatch/StdPatch.h"
#import <stdatomic.h>

typedef struct { Class cls; SEL sel; IMP replacement, original; } DPHookRecord;
// Hooks are added on the main thread after launch while any thread may be inside DPOriginalIMP: the table never moves, and a record counts only once it is whole.
static DPHookRecord DPHooks[1024];
static _Atomic size_t DPHookCount;

void DPHookClass(Class cls, SEL sel, IMP replacement) {
    Method method = cls ? class_getInstanceMethod(cls, sel) : NULL;
    if (!method) return;
    size_t count = atomic_load_explicit(&DPHookCount, memory_order_relaxed);
    // Already hooked here or in a superclass: a second copy would find itself as the original and recurse.
    for (size_t i = 0; i < count; i++) {
        if (DPHooks[i].sel != sel || DPHooks[i].replacement != replacement) continue;
        for (Class c = cls; c; c = class_getSuperclass(c)) if (c == DPHooks[i].cls) return;
    }
    if (count == sizeof DPHooks / sizeof *DPHooks) return NSLog(@"DiaPatches: hook table is full; not hooking -[%s %@]", class_getName(cls), NSStringFromSelector(sel));
    IMP original = method_getImplementation(method);
    // The record goes in first: once the replacement is live, any thread that reaches it must find it.
    DPHooks[count] = (DPHookRecord){cls, sel, replacement, original};
    atomic_store_explicit(&DPHookCount, count + 1, memory_order_release);
    if (!class_addMethod(cls, sel, replacement, method_getTypeEncoding(method))) method_setImplementation(method, replacement);
}

void DPHook(const char *className, SEL sel, IMP replacement) {
    Class cls = objc_getClass(className);
    if (!class_getInstanceMethod(cls, sel)) NSLog(@"DiaPatches: can't hook -[%s %@]; Dia may have renamed it", className, NSStringFromSelector(sel));
    else DPHookClass(cls, sel, replacement);
}

IMP DPOriginalIMP(id object, SEL sel, IMP replacement) {
    size_t count = atomic_load_explicit(&DPHookCount, memory_order_acquire);
    for (Class c = object_getClass(object); c; c = class_getSuperclass(c))
        for (size_t i = 0; i < count; i++)
            if (DPHooks[i].cls == c && DPHooks[i].sel == sel && DPHooks[i].replacement == replacement) return DPHooks[i].original;
    abort();
}

IMP DPDiaIMP(Class cls, SEL sel) {
    size_t count = atomic_load_explicit(&DPHookCount, memory_order_acquire);
    for (size_t i = 0; i < count; i++)
        if (DPHooks[i].cls == cls && DPHooks[i].sel == sel) return DPHooks[i].original;
    return class_getMethodImplementation(cls, sel);
}
