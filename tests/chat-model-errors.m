#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "Patches/DiaChatModel/ChatErrorsScript.h"
#include <assert.h>

int main(void) { @autoreleasepool {
    JSContext *context = [JSContext new];
    context.exceptionHandler = ^(JSContext *ctx, JSValue *error) { NSLog(@"%@", error); abort(); };
    [context evaluateScript:@"var window = {}; var reports = 0;"
        "function button(text) { return {textContent:text,attrs:{},listeners:[],getAttribute(k){return this.attrs[k]??null},"
        "setAttribute(k,v){this.attrs[k]=v},removeAttribute(k){delete this.attrs[k]},addEventListener(k,f,c){this.listeners.push(f)},"
        "click(){let e={stopped:false,preventDefault(){},stopImmediatePropagation(){this.stopped=true}};"
        "for(let f of this.listeners)f(e);if(!e.stopped)reports++}}}"
        "var report=button('Report Error'),retry=button('Try Again'),outside=button('Report Error');"
        "var buttons=[report,retry];var document={documentElement:{},querySelectorAll(s){"
        "if(s!=='[aria-label=\"Error actions\"] button')throw Error('unscoped selector');return buttons}};"
        "function MutationObserver(f){this.callback=f;this.observe=()=>{};this.disconnect=()=>{}};"];
    NSString *(^script)(BOOL) = ^NSString *(BOOL enabled) {
        return [DPChatErrorsScript stringByReplacingOccurrencesOfString:@"__DIATWEAKS_MODEL_ENABLED__" withString:enabled ? @"true" : @"false"];
    };
    [context evaluateScript:script(YES)];
    assert([[context evaluateScript:@"report.textContent"].toString isEqual:@"Change Model"]);
    assert([context evaluateScript:@"outside.textContent==='Report Error' && retry.textContent==='Try Again'"].toBool);
    [context evaluateScript:@"report.click();"];
    assert([[context evaluateScript:script(YES)].toString isEqual:@"change-model"]);
    assert([[context evaluateScript:script(YES)].toString isEqual:@""]);
    assert([context evaluateScript:@"reports"].toInt32 == 0);
    [context evaluateScript:script(NO)];
    assert([[context evaluateScript:@"report.textContent"].toString isEqual:@"Report Error"]);
    assert([context evaluateScript:@"report.getAttribute('aria-label')===null"].toBool);
    [context evaluateScript:@"report.click();"];
    assert([context evaluateScript:@"reports"].toInt32 == 1);
    [context evaluateScript:script(YES)];
    assert([context evaluateScript:@"report.listeners.length"].toInt32 == 1);
    [context evaluateScript:@"report.textContent='Try Again';window.__diaTweaksModelErrorAction.observer.callback();report.click();"];
    assert([[context evaluateScript:@"report.textContent"].toString isEqual:@"Try Again"]);
    assert([[context evaluateScript:script(YES)].toString isEqual:@""]);
    puts("PASS scoped Change Model action, restoration, idempotence and rerendering");
} }
