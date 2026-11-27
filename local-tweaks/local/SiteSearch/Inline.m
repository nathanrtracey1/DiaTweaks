#import "SiteSearch.h"

#define DPDiaCommandBarTextView "_TtCC15BoostCommandBar17TextContainerViewP33_D1D5FD646E4C80541B0F80FBBC4EB9C28TextView"

// Dia completes what's typed into an address, "p" into prezi.com, as selected text after the cursor. With a site chosen
// that's never wanted. Dia's requests for suggestions are asked not to complete; should a completion come anyway, it's
// turned down the way a person would, with Backspace, which takes only the completion.

static BOOL DPSearchingSite(void);

NSString *DPTypedText(NSTextView *text) {
    NSRange selected = text.selectedRange;
    BOOL completion = selected.length && selected.location && NSMaxRange(selected) == text.string.length;
    return completion ? [text.string substringToIndex:selected.location] : text.string;
}

#pragma mark Asking

typedef BOOL (*DPAutocomplete)(id, SEL, NSString *, long, BOOL, id);
static NSMapTable<Class, NSValue *> *DPOriginals;

// Dia's other request for suggestions, besides the browser's: whichever classes answer it, found at launch.
static BOOL DPAny_autocomplete(id self, SEL _cmd, NSString *text, long cursor, BOOL prevent, id completion) {
    DPAutocomplete original = NULL;
    for (Class cls = object_getClass(self); cls && !original; cls = class_getSuperclass(cls))
        original = (DPAutocomplete)[DPOriginals objectForKey:cls].pointerValue;
    return original ? original(self, _cmd, text, cursor, prevent || DPSearchingSite(), completion) : NO;
}

static void DPHookClassAutocomplete(Class cls, SEL sel) {
    unsigned count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned i = 0; i < count; i++) {
        if (method_getName(methods[i]) != sel) continue;
        // Text, a cursor as a whole number, a BOOL and a block, or it isn't the request this expects.
        char cursor[8] = {0}, prevent[8] = {0};
        method_getArgumentType(methods[i], 3, cursor, sizeof cursor);
        method_getArgumentType(methods[i], 4, prevent, sizeof prevent);
        if (method_getNumberOfArguments(methods[i]) == 6 && strchr("qiQIl", cursor[0]) && strchr("Bc", prevent[0]))
            [DPOriginals setObject:[NSValue valueWithPointer:method_setImplementation(methods[i], (IMP)DPAny_autocomplete)] forKey:cls];
    }
    free(methods);
}

// Searched for in Dia's own code (ArcCore answers it in Dia 1.57), reading method lists: asking every class in the app
// for a method makes some throw.
static void DPHookOtherAutocomplete(void) {
    SEL sel = @selector(autocomplete:cursorPosition:preventInlineAutocomplete:completion:);
    DPOriginals = [NSMapTable strongToStrongObjectsMapTable];
    const char *bundle = NSBundle.mainBundle.bundlePath.fileSystemRepresentation;
    unsigned imageCount = 0;
    const char **images = objc_copyImageNames(&imageCount);
    for (unsigned i = 0; i < imageCount; i++) {
        if (strncmp(images[i], bundle, strlen(bundle)) != 0) continue;
        unsigned count = 0;
        const char **names = objc_copyClassNamesForImage(images[i], &count);
        for (unsigned j = 0; j < count; j++) {
            Class cls = objc_getClass(names[j]);
            if (cls) DPHookClassAutocomplete(cls, sel);
        }
        free(names);
    }
    free(images);
}

#pragma mark Turning down

static __weak NSTextView *DPGuarded;

static BOOL DPSearchingSite(void) { return DPSiteSearch.on && DPSiteOfField(DPGuarded); }

void DPGuardField(NSTextView *text, BOOL guard) {
    if (guard) DPGuarded = text;
    else if (DPGuarded == text) DPGuarded = nil;
}

// Someone selecting text themselves: with the mouse, or Shift and a key.
static BOOL DPSelectingByHand(void) {
    NSEvent *event = NSApp.currentEvent;
    if (event.type == NSEventTypeLeftMouseDown || event.type == NSEventTypeLeftMouseDragged) return YES;
    return event.type == NSEventTypeKeyDown && (event.modifierFlags & (NSEventModifierFlagShift | NSEventModifierFlagCommand));
}

// Runs the block once the run loop has nothing left to do but draw: Core Animation commits what's drawn in a later
// observer of the same moment.
static void DPBeforeDrawing(void (^block)(void)) {
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, NO, 0, ^(CFRunLoopObserverRef _, CFRunLoopActivity __) { block(); });
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    CFRelease(observer);
}

static void DPTextView_setSelectedRanges(NSTextView *self, SEL _cmd, NSArray<NSValue *> *ranges, NSSelectionAffinity affinity, BOOL still) {
    DPCallOriginal(DPTextView_setSelectedRanges, self, ranges, affinity, still);
    if (!DPSiteSearch.on || still || !DPSiteOfField(self) || DPSelectingByHand() || self.hasMarkedText) return;
    NSRange range = ranges.firstObject.rangeValue;
    if (ranges.count != 1 || !range.length || !range.location || NSMaxRange(range) != self.string.length) return;
    NSString *before = self.string;
    __weak NSTextView *weakSelf = self;
    DPBeforeDrawing(^{
        NSTextView *text = weakSelf;
        if (![text.string isEqual:before] || !NSEqualRanges(text.selectedRange, range) || !DPSiteOfField(text)) return;
        [text doCommandBySelector:@selector(deleteBackward:)];
    });
}

void DPInstallSiteInline(void) {
    DPHook(DPDiaCommandBarTextView, @selector(setSelectedRanges:affinity:stillSelecting:), (IMP)DPTextView_setSelectedRanges);
    DPOnLaunch(^{ DPHookOtherAutocomplete(); });  // Swift classes are all loaded by then.
}
