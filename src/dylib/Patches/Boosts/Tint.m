#import "Patches/Boosts/Boosts.h"

// A boost's color on the page. Dia ships the engine that injects Arc's Boosts, but the part that recolored a page lived
// in Arc's own app, so this does it: every background and text color moves to the boost's hue, as light as it was
// against the rest. Foundation only, like Rules.m.

// h in degrees and s in percent for backgrounds, ts for text; b is the lightness white turns into and t black's.
NSDictionary *DPBoostPalette(NSDictionary *color) {
    BOOL dark = [color[@"dark"] boolValue];
    double sat = [color[@"sat"] doubleValue];
    return @{ @"h" : color[@"hue"], @"s" : @(sat), @"ts" : @(sat * 0.6), @"dark" : @(dark),
              @"b" : @((dark ? 0.08 : 0.76) + 0.002 * [color[@"light"] doubleValue]), @"t" : @(dark ? 0.95 : 0.1) };
}

// The page's own ground and text, there before the page is parsed. The script takes transitions away while it works,
// or each color it reads would be one on its way to another.
NSString *DPBoostTintRule(NSDictionary *color) {
    if (!color) return @"";
    NSDictionary *p = DPBoostPalette(color);
    return [NSString stringWithFormat:@"html, body { background-color: hsl(%@ %@%% %.1f%%) !important; color: hsl(%@ %@%% %.1f%%) !important; }\n"
                                       "html[data-dp-still] * { transition: none !important; }\n",
                                      p[@"h"], p[@"s"], [p[@"b"] doubleValue] * 100, p[@"h"], p[@"ts"], [p[@"t"] doubleValue] * 100];
}

// Called with the palette, or null to give the page its colors back. What it knows is kept on the page itself, the
// palette on <html> and each element's own colors on the element, because Dia runs a boost's script and the editor's
// live changes in different JavaScript worlds, which share the page and nothing else. Images, video and SVG shapes keep
// their colors.
// shortcut: an element keeps the color it had when first seen, and borders, gradients and shadow roots are left alone;
// watch class and style changes too if hovered or selected things look wrong.
static NSString *const DPTintScript = @"(p => {"
    "const html = document.documentElement, media = /^(IMG|VIDEO|CANVAS|IFRAME|PICTURE)$/;"
    "if (!p && !html.dataset.dpTint) return;"
    "if (p) html.dataset.dpTint = JSON.stringify(p); else delete html.dataset.dpTint;"
    "const rgb = s => { const m = /^rgba?\\(([^)]+)\\)/.exec(s); return m && m[1].split(/[\\s,\\/]+/).map(Number); };"
    "const mapped = (c, bg, p) => { const L = (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255;"
    "  const l = bg ? p.b + (p.dark ? 0.12 : -0.12) * (1 - L) : p.t + (p.dark ? -0.25 : 0.25) * L;"
    "  return `hsla(${p.h}, ${bg ? p.s : p.ts}%, ${l * 100}%, ${c[3] ?? 1})`; };"
    "const put = (el, prop, was, bg, p) => { const c = rgb(was); if (c && c[3] !== 0) el.style.setProperty(prop, mapped(c, bg, p), 'important'); };"
    "const paint = (root, fresh) => {"
    "  const p = JSON.parse(html.dataset.dpTint || 'null');"
    "  const els = [root, ...root.querySelectorAll('*')].filter(el => el.style && el.parentElement && el !== document.body"
    "    && !el.ownerSVGElement && !media.test(el.tagName));"
    "  html.dataset.dpStill = '';"
    "  if (fresh || !p) for (const el of els) if ('dpBg' in el.dataset) { delete el.dataset.dpBg; delete el.dataset.dpFg;"
    "    el.style.removeProperty('background-color'); el.style.removeProperty('color'); }"
    "  if (p) {"  // Every color is read before any is written: a text color is only an element's own if its parent's differs.
    "    const read = els.filter(el => !('dpBg' in el.dataset)).map(el => { const own = getComputedStyle(el), up = getComputedStyle(el.parentElement);"
    "      return [el, own.backgroundColor, own.color === up.color ? '' : own.color]; });"
    "    for (const [el, bg, fg] of read) { el.dataset.dpBg = bg; el.dataset.dpFg = fg; }"
    "    for (const el of els) { put(el, 'background-color', el.dataset.dpBg, true, p); put(el, 'color', el.dataset.dpFg, false, p); }"
    "  }"
    "  getComputedStyle(html).color;"  // The new colors settle before transitions come back.
    "  delete html.dataset.dpStill;"
    "};"
    "if (!window.__dpTint) {"
    "  window.__dpTint = true;"
    "  new MutationObserver(all => { if (document.readyState === 'loading' || !html.dataset.dpTint) return;"
    "    for (const one of all) for (const node of one.addedNodes) if (node.nodeType === 1) paint(node); })"
    "    .observe(document, { childList: true, subtree: true });"
    "  for (const when of ['DOMContentLoaded', 'load']) addEventListener(when, () => paint(html, true));"  // Stylesheets may come late.
    "}"
    "if (document.readyState !== 'loading') paint(html);"
    "})";

NSString *DPBoostTintScript(NSDictionary *boost) {
    NSDictionary *color = boost[@"color"];
    NSData *json = color ? [NSJSONSerialization dataWithJSONObject:DPBoostPalette(color) options:0 error:nil] : nil;
    return [NSString stringWithFormat:@"%@(%@)", DPTintScript, json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"null"];
}
