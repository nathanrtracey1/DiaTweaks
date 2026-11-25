#import "Patches/Boosts/Boosts.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// .diaboost files: one site's Boost as JSON, to keep or to share. Dia doesn't declare the type, so a file on disk gets
// the plain dynamic type for the extension; asking for one conforming to JSON would never match it.
static UTType *DPBoostFileType(void) { return [UTType typeWithFilenameExtension:@"diaboost"]; }

static void DPRun(NSAlert *alert, NSWindow *window, void (^done)(NSModalResponse response)) {
    if (window.visible) [alert beginSheetModalForWindow:window completionHandler:done];
    else done([alert runModal]);
}

static NSAlert *DPAlert(NSString *message, NSString *info) {
    NSAlert *alert = [NSAlert new];
    alert.messageText = message;
    alert.informativeText = info ?: @"";
    return alert;
}

void DPExportBoost(NSString *domain, NSWindow *window) {
    NSDictionary *boost = DPBoostFor(domain);
    if (!boost) return DPRun(DPAlert(@"Nothing to export yet", @"Change something in this Boost first."), window, ^(NSModalResponse _) {});
    NSSavePanel *save = [NSSavePanel savePanel];
    save.nameFieldStringValue = [domain stringByAppendingPathExtension:@"diaboost"];
    save.allowedContentTypes = @[ DPBoostFileType() ];
    if ([boost[@"js"] length]) save.message = @"This Boost includes JavaScript. Only share it with people you trust.";
    void (^write)(NSModalResponse) = ^(NSModalResponse response) {
        NSError *error;
        if (response == NSModalResponseOK && ![DPBoostFileData(domain, boost) writeToURL:save.URL options:NSDataWritingAtomic error:&error])
            [[NSAlert alertWithError:error] runModal];
    };
    if (window.visible) [save beginSheetModalForWindow:window completionHandler:write];
    else write([save runModal]);
}

// Imported from the Boost editor, it opens again with the new Boost.
static void DPFinishImport(NSString *domain, NSDictionary *boost, NSWindow *window) {
    DPSaveBoost(domain, boost);
    if (DPIsKind(window, DPDiaWindow) && [DPFrontDomain() isEqual:domain]) DPShowBoostEditor(domain);
}

// A file can come from anyone: say what it replaces, and warn before it can run code on the site.
static void DPConfirmImport(NSString *domain, NSDictionary *boost, NSWindow *window) {
    BOOL replaces = DPBoostFor(domain) != nil, runs = [boost[@"js"] length] > 0;
    if (!replaces && !runs) return DPFinishImport(domain, boost, window);
    NSMutableArray *info = [NSMutableArray new];
    if (replaces) [info addObject:@"Your current Boost for this site will be replaced."];
    if (runs) [info addObject:@"It runs JavaScript on the site, which can read what you see there and send it elsewhere. Only import it if you trust where it came from."];
    NSAlert *alert = DPAlert([NSString stringWithFormat:replaces ? @"Replace your Boost for %@?" : @"Import a Boost for %@?", domain], [info componentsJoinedByString:@"\n\n"]);
    if (runs) alert.alertStyle = NSAlertStyleCritical;
    [alert addButtonWithTitle:replaces ? @"Replace" : @"Import"];
    [alert addButtonWithTitle:@"Cancel"];
    DPRun(alert, window, ^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) DPFinishImport(domain, boost, window);
    });
}

void DPImportBoost(NSWindow *window) {
    NSOpenPanel *open = [NSOpenPanel openPanel];
    open.allowedContentTypes = @[ DPBoostFileType(), UTTypeJSON ];
    open.message = @"Choose a Boost file (.diaboost).";
    void (^read)(NSModalResponse) = ^(NSModalResponse response) {
        if (response != NSModalResponseOK) return;
        NSString *domain, *problem;
        NSDictionary *boost = DPBoostFromFileData([NSData dataWithContentsOfURL:open.URL options:0 error:nil], &domain, &problem);
        dispatch_async(dispatch_get_main_queue(), ^{  // After the open panel's sheet is gone.
            if (!boost) return DPRun(DPAlert(@"Couldn’t import this Boost", problem), window, ^(NSModalResponse _) {});
            DPConfirmImport(domain, boost, window);
        });
    };
    if (window.visible) [open beginSheetModalForWindow:window completionHandler:read];
    else read([open runModal]);
}
