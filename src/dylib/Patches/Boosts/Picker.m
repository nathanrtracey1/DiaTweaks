#import "Patches/Boosts/Boosts.h"

// Like Arc's selector picker: highlight what's under the pointer, and on each click name it with the steadiest parts it
// has (an id, test id or label before class names that look generated), adding parents until it names only that
// element. It keeps going until Escape, so several things can go in one go; each click waits in __dpZaps for the poll.
static NSString *const DPPickerScript = @"(() => {"
    "if (window.__dpZap) return;"
    "window.__dpZap = true;"
    "window.__dpZaps = [];"
    "const box = document.createElement('div');"
    "box.style.cssText = 'position:fixed;z-index:2147483647;pointer-events:none;background:rgba(255,59,48,.2);outline:2px solid #ff3b30;border-radius:4px';"
    "const hint = document.createElement('div');"
    "hint.textContent = 'Click what you want to hide \u00B7 Esc when you\u2019re done';"
    "hint.style.cssText = 'position:fixed;top:14px;left:50%;transform:translateX(-50%);z-index:2147483647;pointer-events:none;"
    "font:500 13px -apple-system,system-ui,sans-serif;color:#fff;background:rgba(20,20,20,.82);padding:8px 16px;border-radius:999px';"
    "const cursor = document.createElement('style');"
    "cursor.textContent = '* { cursor: pointer !important; }';"  // Everything under the pointer can be clicked away.
    "document.documentElement.append(box, hint, cursor);"
    "const generated = s => /\\d{3}|[bcdfghjklmnpqrstvwxz]{5}|__|^(css|sc|jsx|tw)-/i.test(s);"
    "const one = sel => { try { return document.querySelectorAll(sel).length === 1; } catch { return false; } };"
    "const step = el => {"
    "  if (el.id && !generated(el.id)) return '#' + CSS.escape(el.id);"
    "  for (const name of ['data-testid', 'aria-label']) { const v = el.getAttribute(name); if (v) return `${el.localName}[${name}=\"${CSS.escape(v)}\"]`; }"
    "  return el.localName + [...el.classList].filter(c => !generated(c)).slice(0, 2).map(c => '.' + CSS.escape(c)).join('');"
    "};"
    "const name = el => {"
    "  let sel = '';"
    "  for (let node = el; node && node !== document.documentElement; node = node.parentElement) {"
    "    let part = step(node); const siblings = node.parentElement ? [...node.parentElement.children] : [];"
    "    if (!part.startsWith('#') && siblings.filter(s => s.matches(part)).length > 1) part += `:nth-child(${siblings.indexOf(node) + 1})`;"
    "    sel = sel ? `${part} > ${sel}` : part;"
    "    if (one(sel)) break;"
    "  }"
    "  return sel;"
    "};"
    "const kinds = { A: 'Link', ASIDE: 'Sidebar', BUTTON: 'Button', FOOTER: 'Footer', FORM: 'Form', H1: 'Heading', H2: 'Heading',"
    "  H3: 'Heading', H4: 'Heading', HEADER: 'Header', IFRAME: 'Embed', IMG: 'Image', INPUT: 'Field', LI: 'List item', NAV: 'Menu',"
    "  OL: 'List', P: 'Paragraph', UL: 'List', VIDEO: 'Video', svg: 'Icon' };"
    "const label = el => { const kind = kinds[el.tagName] || 'Section';"
    "  const text = (el.getAttribute('aria-label') || el.innerText || el.alt || el.title || '').trim().replace(/\\s+/g, ' ');"
    "  return text ? `${kind} \u201C${text.length > 40 ? text.slice(0, 40) + '\u2026' : text}\u201D` : kind; };"
    "let target = null;"
    "let x = 0, y = 0;"
    "const clear = () => { target = null; Object.assign(box.style, { width: '0px', height: '0px' }); };"
    "const show = el => { target = el; if (!el) return clear(); const r = el.getBoundingClientRect();"
    "  Object.assign(box.style, { left: r.left + 'px', top: r.top + 'px', width: r.width + 'px', height: r.height + 'px' }); };"
    "const move = e => { x = e.clientX; y = e.clientY; show(e.target); };"
    "const block = e => { e.preventDefault(); e.stopImmediatePropagation(); };"
    "const presses = ['pointerdown', 'mousedown', 'pointerup', 'mouseup'];"
    "const leave = e => { if (!e.relatedTarget) clear(); };"  // Off the page, such as into the Boost popover.
    "const finish = () => { removeEventListener('mousemove', move, true); removeEventListener('click', click, true);"
    "  removeEventListener('mouseout', leave, true); removeEventListener('keydown', key, true);"
    "  presses.forEach(k => removeEventListener(k, block, true)); box.remove(); hint.remove(); cursor.remove();"
    "  window.__dpZap = false; delete window.__dpZapStop; };"
    // The Boost hides what was clicked a moment later; whatever that uncovers under the pointer is outlined then, without
    // waiting for the pointer to move.
    "const click = e => { block(e); const zapped = target; if (!zapped) return;"
    "  window.__dpZaps.push({ selector: name(zapped), label: label(zapped) }); clear();"
    "  const since = performance.now();"
    "  const uncover = () => { if (!window.__dpZap || target) return; const el = document.elementFromPoint(x, y);"
    "    if (el && el !== zapped && !zapped.contains(el)) return show(el);"
    "    if (performance.now() - since < 2000) requestAnimationFrame(uncover); };"
    "  requestAnimationFrame(uncover); };"
    "window.__dpZapStop = finish;"
    "const key = e => { if (e.key === 'Escape') { block(e); finish(); } };"
    "addEventListener('mousemove', move, true); addEventListener('click', click, true); addEventListener('mouseout', leave, true);"
    "addEventListener('keydown', key, true);"
    "presses.forEach(k => addEventListener(k, block, true));"
    "})()";

// What was clicked since the last poll. A page that navigated away has no picker any more, which ends it as if Escape.
static NSString *const DPPollScript = @"(() => { const zaps = window.__dpZaps || []; window.__dpZaps = [];"
    "return JSON.stringify({ zaps, picking: !!window.__dpZap }); })()";

static void DPPoll(id contents, void (^picked)(NSDictionary *), void (^done)(void)) {
    __weak id weak = contents;
    DPRunScript(contents, DPPollScript, ^(NSString *result) {
        NSData *data = [result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *state = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![state isKindOfClass:NSDictionary.class]) return done();
        for (id zap in [state[@"zaps"] isKindOfClass:NSArray.class] ? state[@"zaps"] : @[]) picked(zap);
        if (![state[@"picking"] boolValue]) return done();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 4), dispatch_get_main_queue(), ^{ DPPoll(weak, picked, done); });
    });
}

void DPPickElements(id contents, void (^picked)(NSDictionary *zap), void (^done)(void)) {
    __weak id weak = contents;
    DPRunScript(contents, DPPickerScript, ^(NSString *_) { DPPoll(weak, picked, done); });
}

void DPStopPicking(id contents) {
    DPRunScript(contents, @"window.__dpZapStop && window.__dpZapStop()", ^(NSString *_) {});
}
