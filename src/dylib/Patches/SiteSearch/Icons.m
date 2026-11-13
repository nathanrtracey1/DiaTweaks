#import "SiteSearch.h"
#import <dlfcn.h>

// Site icons come from Chromium's Favicons database in each profile, read without a lock (immutable) so Chromium's own
// writes are never held up. SQLite is loaded from the system: Chromium's copy inside Dia is renamed.

typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;

static struct {
    int (*open)(const char *, sqlite3 **, int, const char *);
    int (*prepare)(sqlite3 *, const char *, int, sqlite3_stmt **, const char **);
    int (*bind)(sqlite3_stmt *, int, const char *, int, void (*)(void *));
    int (*step)(sqlite3_stmt *);
    const void *(*blob)(sqlite3_stmt *, int);
    int (*bytes)(sqlite3_stmt *, int);
    int (*finalize)(sqlite3_stmt *);
    int (*close)(sqlite3 *);
} DPSQLite;

static BOOL DPLoadSQLite(void) {
    static BOOL loaded;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *lib = dlopen("/usr/lib/libsqlite3.dylib", RTLD_LAZY | RTLD_LOCAL);
        if (!lib) return;
        DPSQLite.open = dlsym(lib, "sqlite3_open_v2");
        DPSQLite.prepare = dlsym(lib, "sqlite3_prepare_v2");
        DPSQLite.bind = dlsym(lib, "sqlite3_bind_text");
        DPSQLite.step = dlsym(lib, "sqlite3_step");
        DPSQLite.blob = dlsym(lib, "sqlite3_column_blob");
        DPSQLite.bytes = dlsym(lib, "sqlite3_column_bytes");
        DPSQLite.finalize = dlsym(lib, "sqlite3_finalize");
        DPSQLite.close = dlsym(lib, "sqlite3_close");
        loaded = DPSQLite.open && DPSQLite.prepare && DPSQLite.bind && DPSQLite.step && DPSQLite.blob && DPSQLite.bytes && DPSQLite.finalize && DPSQLite.close;
    });
    return loaded;
}

// The largest icon of the site's home page, else of any page on it.
static NSData *DPIconData(NSString *database, NSString *host) {
    NSString *uri = [NSString stringWithFormat:@"file:%@?immutable=1", [database stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet]];
    sqlite3 *db = NULL;
    if (DPSQLite.open(uri.UTF8String, &db, 0x00000001 | 0x00000040, NULL) != 0) return DPSQLite.close(db), nil;  // READONLY | URI
    const char *query = "SELECT b.image_data FROM icon_mapping m JOIN favicon_bitmaps b ON b.icon_id = m.icon_id "
                        "WHERE m.page_url LIKE 'https://' || ?1 || '/%' OR m.page_url LIKE 'https://www.' || ?1 || '/%' "
                        "ORDER BY m.page_url IN ('https://' || ?1 || '/', 'https://www.' || ?1 || '/') DESC, b.width DESC LIMIT 1";
    sqlite3_stmt *statement = NULL;
    NSData *data = nil;
    if (DPSQLite.prepare(db, query, -1, &statement, NULL) == 0) {
        DPSQLite.bind(statement, 1, host.UTF8String, -1, (void (*)(void *))-1);  // SQLITE_TRANSIENT
        if (DPSQLite.step(statement) == 100)  // SQLITE_ROW
            data = [NSData dataWithBytes:DPSQLite.blob(statement, 0) length:DPSQLite.bytes(statement, 0)];
    }
    DPSQLite.finalize(statement);
    DPSQLite.close(db);
    return data;
}

static NSImage *DPStoredIcon(NSString *host) {
    static NSCache<NSString *, NSImage *> *icons;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ icons = [NSCache new]; });
    NSImage *icon = [icons objectForKey:host];
    if (icon || !DPLoadSQLite()) return icon;
    NSString *data = DPAppSupport(@"Dia/User Data");
    for (NSString *profile in [NSFileManager.defaultManager contentsOfDirectoryAtPath:data error:nil]) {
        NSString *database = [[data stringByAppendingPathComponent:profile] stringByAppendingPathComponent:@"Favicons"];
        if (![NSFileManager.defaultManager fileExistsAtPath:database]) continue;
        NSData *bytes = DPIconData(database, host);
        icon = bytes.length ? [[NSImage alloc] initWithData:bytes] : nil;
        if (icon) break;
    }
    if (icon) [icons setObject:icon forKey:host];  // One not found is looked for again: it's there once the site is visited.
    return icon;
}

// The site's own icon, else its parent's: Google's for maps.google.com, whose pages live at google.com/maps.
NSImage *DPSiteIcon(DPSite *site) {
    NSImage *icon = DPStoredIcon(site.host);
    NSRange dot = [site.host rangeOfString:@"."];
    if (icon || dot.location == NSNotFound) return icon;
    NSString *parent = [site.host substringFromIndex:NSMaxRange(dot)];
    return [parent containsString:@"."] ? DPStoredIcon(parent) : nil;
}

#define DPDiaSuggestionsView "_TtC15BoostCommandBar15SuggestionsView"
#define DPDiaIconContainer   "_TtC15BoostCommandBar17IconContainerView"

// The site's icon from Dia's store of them, else from what Dia shows, else nil. Dia already has it, so nothing is
// fetched. Symbols such as Dia's own globe are templates; a site's icon is a picture, often only on suggestions for its
// pages, not the site itself.
NSImage *DPSiteIconFor(NSTextView *text, DPSite *site) {
    NSImage *stored = DPSiteIcon(site);
    if (stored) return stored;
    NSView *input = text;
    while (input && !DPIsKind(input, DPDiaCommandBarInput)) input = input.superview;
    NSImageView *field = (NSImageView *)DPFindView(DPFindView(input, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaIconContainer); }), ^BOOL(NSView *view) {
        return [view isKindOfClass:NSImageView.class];
    });
    if (field.image && !field.image.isTemplate) return field.image;
    NSTableView *table = (NSTableView *)DPFindView(text.window.contentView, ^BOOL(NSView *view) {
        return [view isKindOfClass:NSTableView.class] && DPIsKind(((NSTableView *)view).delegate, DPDiaSuggestionsView);
    });
    for (NSInteger row = 0; row < table.numberOfRows; row++) {
        NSView *view = [table rowViewAtRow:row makeIfNecessary:YES];
        BOOL names = DPFindView(view, ^BOOL(NSView *sub) {
            return [sub isKindOfClass:NSTextField.class] && [((NSTextField *)sub).stringValue.lowercaseString containsString:site.host];
        }) != nil;
        NSImageView *icon = names ? (NSImageView *)DPFindView(view, ^BOOL(NSView *sub) {
            return [sub isKindOfClass:NSImageView.class] && ((NSImageView *)sub).image && !((NSImageView *)sub).image.isTemplate;
        }) : nil;
        if (icon) return icon.image;
    }
    return nil;
}
