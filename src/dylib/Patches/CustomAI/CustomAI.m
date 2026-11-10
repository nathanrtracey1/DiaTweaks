#import "Patches/CustomAI/CustomAI.h"
#import "Updates/Updates.h"
#import "Settings/Settings.h"
#import <objc/message.h>

extern DPPatch DPCustomAI;

static NSString *const kAIProviderKey = @"customAIProvider";
static NSString *const kAIModelKey = @"customAIModel";
static NSString *const kAIKeyKey = @"customAIKey";
static NSString *const kAIEndpointKey = @"customAIEndpoint";

static NSUserDefaults *DPAIDefaults(void) {
    static NSUserDefaults *defaults;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return defaults;
}

static NSString *DPCurrentProvider(void) {
    NSString *p = DPChoice(&DPCustomAI);
    if (!p.length) p = [DPAIDefaults() stringForKey:kAIProviderKey];
    return p.length ? p : @"ollama";
}

static NSString *DPCurrentModel(void) {
    NSString *m = [DPAIDefaults() stringForKey:kAIModelKey];
    if (m.length) return m;
    NSString *provider = DPCurrentProvider();
    if ([provider isEqualToString:@"ollama"]) return @"llama3.2";
    if ([provider isEqualToString:@"lmstudio"]) return @"local-model";
    if ([provider isEqualToString:@"gemini"]) return @"gemini-2.5-flash";
    if ([provider isEqualToString:@"claude"]) return @"claude-3-7-sonnet-20250219";
    if ([provider isEqualToString:@"openai"]) return @"gpt-4o";
    return @"llama3.2";
}

static NSString *DPCurrentKey(void) {
    return [DPAIDefaults() stringForKey:kAIKeyKey] ?: @"";
}

static NSString *DPCurrentEndpoint(void) {
    NSString *ep = [DPAIDefaults() stringForKey:kAIEndpointKey];
    if (ep.length) return ep;
    NSString *provider = DPCurrentProvider();
    if ([provider isEqualToString:@"ollama"]) return @"http://localhost:11434/v1/chat/completions";
    if ([provider isEqualToString:@"lmstudio"]) return @"http://localhost:1234/v1/chat/completions";
    if ([provider isEqualToString:@"gemini"]) return @"https://generativelanguage.googleapis.com/v1beta/openai/chat/completions";
    if ([provider isEqualToString:@"claude"]) return @"https://api.anthropic.com/v1/messages";
    if ([provider isEqualToString:@"openai"]) return @"https://api.openai.com/v1/chat/completions";
    return @"http://localhost:11434/v1/chat/completions";
}

#pragma mark - Custom Settings Rows

@interface DPAITextFieldRow : NSTextField <NSTextFieldDelegate>
@property (nonatomic, copy) NSString *prefKey;
@end

@implementation DPAITextFieldRow
- (void)controlTextDidChange:(NSNotification *)notification {
    [DPAIDefaults() setObject:self.stringValue forKey:self.prefKey];
}
- (void)fieldSubmitted:(id)sender {
    [DPAIDefaults() setObject:self.stringValue forKey:self.prefKey];
}
@end

static NSView *DPAIInputRow(NSString *title, NSString *key, NSString *placeholder, BOOL secure) {
    DPAITextFieldRow *field = secure ? (DPAITextFieldRow *)[NSSecureTextField new] : [DPAITextFieldRow new];
    field.prefKey = key;
    field.delegate = field;
    field.target = field;
    field.action = @selector(fieldSubmitted:);
    field.placeholderString = placeholder;
    field.stringValue = [DPAIDefaults() stringForKey:key] ?: @"";
    field.font = [NSFont systemFontOfSize:12];
    field.controlSize = NSControlSizeSmall;
    field.bezelStyle = NSTextFieldRoundedBezel;
    [field.widthAnchor constraintEqualToConstant:220].active = YES;
    return DPRow(DPLabel(title, 13, NSFontWeightRegular, NSColor.labelColor), field);
}

static NSArray<NSView *> *DPCustomAIRows(void) {
    return @[
        DPAIInputRow(@"Model Name", kAIModelKey, @"e.g. llama3.2, gemini-2.5-flash", NO),
        DPAIInputRow(@"API Key", kAIKeyKey, @"sk-... or AIzaSy...", YES),
        DPAIInputRow(@"Custom Endpoint", kAIEndpointKey, @"http://localhost:11434/v1/chat/completions", NO),
    ];
}

static NSMenu *DPCustomAIChoices(void) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Provider"];
    NSArray *items = @[
        @[ @"Ollama (Local)", @"ollama" ],
        @[ @"LM Studio (Local)", @"lmstudio" ],
        @[ @"Google Gemini (Direct API)", @"gemini" ],
        @[ @"Anthropic Claude (Direct API)", @"claude" ],
        @[ @"OpenAI ChatGPT (Direct API)", @"openai" ],
    ];
    for (NSArray *item in items) {
        NSMenuItem *entry = [[NSMenuItem alloc] initWithTitle:item[0] action:nil keyEquivalent:@""];
        entry.representedObject = item[1];
        [menu addItem:entry];
    }
    return menu;
}

#pragma mark - SSE & Payload Helpers

static NSData *DPGetRequestBody(NSURLRequest *request) {
    if (request.HTTPBody) return request.HTTPBody;
    if (request.HTTPBodyStream) {
        NSInputStream *stream = request.HTTPBodyStream;
        [stream open];
        NSMutableData *data = [NSMutableData data];
        uint8_t buffer[4096];
        while ([stream hasBytesAvailable]) {
            NSInteger len = [stream read:buffer maxLength:sizeof(buffer)];
            if (len > 0) [data appendBytes:buffer length:len];
            else break;
        }
        [stream close];
        return data;
    }
    return nil;
}

static NSData *DPSynthesizeAnthropicSSE(NSString *text, BOOL start, BOOL end) {
    NSMutableString *out = [NSMutableString string];
    if (start) {
        [out appendString:@"event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_custom\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[]}}\n\n"];
        [out appendString:@"event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n"];
    }
    if (text.length > 0) {
        NSDictionary *dict = @{
            @"type": @"content_block_delta",
            @"index": @0,
            @"delta": @{
                @"type": @"text_delta",
                @"text": text
            }
        };
        NSData *strJson = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
        if (strJson) {
            NSString *jsonStr = [[NSString alloc] initWithData:strJson encoding:NSUTF8StringEncoding];
            [out appendFormat:@"event: content_block_delta\ndata: %@\n\n", jsonStr ?: @"{}"];
        }
    }
    if (end) {
        [out appendString:@"event: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":0}\n\n"];
        [out appendString:@"event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"}}\n\n"];
        [out appendString:@"event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"];
    }
    return [out dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - Custom AI URLProtocol Interceptor

@interface DPAIProxyProtocol : NSURLProtocol <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic, strong) NSMutableData *buffer;
@property (nonatomic, assign) BOOL isClaudePassthrough;
@property (nonatomic, assign) BOOL hasSentStart;
@end

@implementation DPAIProxyProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (!DPCustomAI.on) return NO;
    if ([NSURLProtocol propertyForKey:@"DPAIHandled" inRequest:request]) return NO;
    NSString *host = request.URL.host.lowercaseString;
    NSString *path = request.URL.path.lowercaseString;
    if (!host || !path) return NO;
    if (![host containsString:@"diabrowser.engineering"]) return NO;

    if ([path containsString:@"web-results"] || [path containsString:@"traces"]) return NO;
    return [path containsString:@"stream"] || [path containsString:@"aiproxy"] || [path containsString:@"chat"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSString *provider = DPCurrentProvider();
    NSString *model = DPCurrentModel();
    NSString *apiKey = DPCurrentKey();
    NSString *endpoint = DPCurrentEndpoint();
    self.isClaudePassthrough = [provider isEqualToString:@"claude"];
    self.buffer = [NSMutableData new];
    self.hasSentStart = NO;

    NSData *bodyData = DPGetRequestBody(self.request);
    NSDictionary *json = bodyData ? [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:nil] : nil;

    NSMutableURLRequest *outbound = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpoint]];
    outbound.HTTPMethod = @"POST";
    [outbound setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [NSURLProtocol setProperty:@YES forKey:@"DPAIHandled" inRequest:outbound];

    if (self.isClaudePassthrough) {
        // Direct Anthropic Messages API
        if (apiKey.length) [outbound setValue:apiKey forHTTPHeaderField:@"x-api-key"];
        [outbound setValue:@"2023-06-01" forHTTPHeaderField:@"anthropic-version"];

        NSMutableDictionary *reqBody = [json mutableCopy] ?: [NSMutableDictionary new];
        reqBody[@"model"] = model;
        if (!reqBody[@"max_tokens"]) reqBody[@"max_tokens"] = @4096;
        outbound.HTTPBody = [NSJSONSerialization dataWithJSONObject:reqBody options:0 error:nil];
    } else {
        // OpenAI-compatible endpoint (Ollama, LM Studio, Gemini, OpenAI)
        if (apiKey.length) {
            [outbound setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
        }

        NSMutableArray *convertedMessages = [NSMutableArray array];
        id systemPrompt = json[@"system"];
        if ([systemPrompt isKindOfClass:NSString.class] && [(NSString *)systemPrompt length]) {
            [convertedMessages addObject:@{ @"role": @"system", @"content": systemPrompt }];
        }

        id rawMsgs = json[@"messages"];
        if ([rawMsgs isKindOfClass:NSArray.class]) {
            for (NSDictionary *msg in (NSArray *)rawMsgs) {
                if (![msg isKindOfClass:NSDictionary.class]) continue;
                NSString *role = msg[@"role"] ?: @"user";
                id content = msg[@"content"];
                if ([content isKindOfClass:NSString.class]) {
                    [convertedMessages addObject:@{ @"role": role, @"content": content }];
                } else if ([content isKindOfClass:NSArray.class]) {
                    NSMutableString *textAccum = [NSMutableString string];
                    for (NSDictionary *part in (NSArray *)content) {
                        if ([part isKindOfClass:NSDictionary.class] && [part[@"type"] isEqualToString:@"text"] && part[@"text"]) {
                            [textAccum appendString:part[@"text"]];
                        }
                    }
                    [convertedMessages addObject:@{ @"role": role, @"content": textAccum ?: @"" }];
                }
            }
        }

        NSDictionary *reqBody = @{
            @"model": model ?: @"",
            @"messages": convertedMessages,
            @"stream": @YES,
            @"temperature": @0.7
        };
        outbound.HTTPBody = [NSJSONSerialization dataWithJSONObject:reqBody options:0 error:nil];
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];
    self.task = [self.session dataTaskWithRequest:outbound];
    [self.task resume];
}

- (void)stopLoading {
    [self.task cancel];
    [self.session invalidateAndCancel];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if (self.isClaudePassthrough) {
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    } else {
        NSHTTPURLResponse *fakeResp = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                                    statusCode:200
                                                                   HTTPVersion:@"HTTP/1.1"
                                                                  headerFields:@{
                                                                      @"Content-Type": @"text/event-stream",
                                                                      @"Cache-Control": @"no-cache",
                                                                      @"Connection": @"keep-alive"
                                                                  }];
        [self.client URLProtocol:self didReceiveResponse:fakeResp cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (self.isClaudePassthrough) {
        [self.client URLProtocol:self didLoadData:data];
        return;
    }

    [self.buffer appendData:data];
    NSString *bufferedStr = [[NSString alloc] initWithData:self.buffer encoding:NSUTF8StringEncoding];
    if (!bufferedStr) return;

    NSArray<NSString *> *lines = [bufferedStr componentsSeparatedByString:@"\n"];
    NSMutableString *remainder = [NSMutableString string];

    for (NSUInteger i = 0; i < lines.count; i++) {
        NSString *line = lines[i];
        if (i == lines.count - 1 && ![bufferedStr hasSuffix:@"\n"]) {
            [remainder appendString:line];
            break;
        }

        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (![trimmed hasPrefix:@"data:"]) continue;

        NSString *payload = [[trimmed substringFromIndex:5] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([payload isEqualToString:@"[DONE]"]) {
            NSData *endSse = DPSynthesizeAnthropicSSE(@"", NO, YES);
            [self.client URLProtocol:self didLoadData:endSse];
            continue;
        }

        NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
        if (!payloadData) continue;

        NSDictionary *chunk = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];
        if (![chunk isKindOfClass:NSDictionary.class]) continue;

        NSArray *choices = chunk[@"choices"];
        if (![choices isKindOfClass:NSArray.class] || choices.count == 0) continue;

        NSDictionary *delta = choices[0][@"delta"];
        NSString *textChunk = delta[@"content"];
        if ([textChunk isKindOfClass:NSString.class] && textChunk.length > 0) {
            NSData *sse = DPSynthesizeAnthropicSSE(textChunk, !self.hasSentStart, NO);
            self.hasSentStart = YES;
            [self.client URLProtocol:self didLoadData:sse];
        }
    }

    self.buffer = [[remainder dataUsingEncoding:NSUTF8StringEncoding] mutableCopy] ?: [NSMutableData new];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error && error.code != NSURLErrorCancelled) {
        NSString *errText = [NSString stringWithFormat:@"\n\n⚠️ Custom AI Error (%@): %@", DPCurrentProvider(), error.localizedDescription];
        NSData *errSse = DPSynthesizeAnthropicSSE(errText, !self.hasSentStart, YES);
        [self.client URLProtocol:self didLoadData:errSse];
    } else if (!self.isClaudePassthrough) {
        NSData *endSse = DPSynthesizeAnthropicSSE(@"", !self.hasSentStart, YES);
        [self.client URLProtocol:self didLoadData:endSse];
    }
    [self.client URLProtocolDidFinishLoading:self];
}

@end

#pragma mark - Patch Registration & Hooks

static NSArray *DPConfig_protocolClasses(NSURLSessionConfiguration *self, SEL _cmd) {
    NSArray *orig = DPCallOriginal(DPConfig_protocolClasses, self);
    if (!DPCustomAI.on) return orig;
    NSMutableArray *list = orig ? [orig mutableCopy] : [NSMutableArray new];
    Class proto = [DPAIProxyProtocol class];
    if (![list containsObject:proto]) {
        [list insertObject:proto atIndex:0];
    }
    return list;
}

static void DPInstallCustomAI(void) {
    [NSURLProtocol registerClass:[DPAIProxyProtocol class]];
    DPHookClass(NSURLSessionConfiguration.class, @selector(protocolClasses), (IMP)DPConfig_protocolClasses);
}

DP_PATCH(DPCustomAI) {
    .key = @"customAI",
    .order = 13,
    .title = @"Custom AI Models & Proxy Bypass",
    .detail = @"Route Dia’s AI chat and inline prompts to local models (Ollama, LM Studio) or your own API key (Gemini, Claude, ChatGPT).",
    .hint = @"Intercepts requests to Dia's AI proxy in memory and translates streaming tokens in real time.",
    .symbol = @"sparkles.square.filled.on.square",
    .tint = @"systemPurpleColor",
    .section = @"Page",
    .choice = kAIProviderKey,
    .defaultChoice = @"ollama",
    .choices = DPCustomAIChoices,
    .rows = DPCustomAIRows,
    .install = DPInstallCustomAI,
};
