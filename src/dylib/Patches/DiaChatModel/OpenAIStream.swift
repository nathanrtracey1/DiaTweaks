import Foundation

struct ChatProviderResult {
    var text = ""
    var calls: [ChatToolCall] = []
    var inputTokens = 0
    var outputTokens = 0
}

struct ChatToolDelta {
    var id = ""
    var name = ""
    var arguments = ""
}

func runOpenAIChat(_ payload: ChatJSON, provider: ChatJSON, history: ProviderReasoning,
                   delta: @escaping (String) -> Void) async throws -> ChatProviderResult {
    let responses = provider["api"] as? String != "chat-completions"
    let converted = try OpenAIChatRequest(payload, model: provider["model"] as? String ?? "", responses: responses)
    var body = converted.body
    if responses { history.restore(into: &body) }
    if provider["api"] as? String == "chatgpt" { body = chatGPTRequest(body) }
    var request = try ProviderHTTP.request(provider, path: responses ? "responses" : "chat/completions")
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let auditID = UUID().uuidString
    let system = OpenAIChatRequest.text(payload["system"]).lowercased()
    providerAudit("http-request", ["request": auditID, "api": provider["api"] ?? "", "model": body["model"] ?? "",
        "system_bytes": system.utf8.count, "native_identity": system.contains("anthropic") && system.contains("opus")])
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    let session = ProviderHTTP.session()
    defer { session.invalidateAndCancel() }
    let (bytes, response) = try await session.bytes(for: request)
    try ProviderHTTP.check(response)
    var result = ChatProviderResult()
    var completionCalls: [Int: ChatToolDelta] = [:]
    var finished = false
    var streamBytes = 0
    func append(_ text: String) {
        result.text += text
        delta(text)
    }
    for try await line in bytes.lines {
        streamBytes += line.utf8.count
        if streamBytes > 16 * 1024 * 1024 { throw ChatProviderError.invalidResponse }
        guard line.hasPrefix("data:") else { continue }
        let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if data == "[DONE]" { break }
        guard let event = try JSONSerialization.jsonObject(with: Data(data.utf8)) as? ChatJSON else { throw ChatProviderError.invalidResponse }
        if responses {
            switch event["type"] as? String {
            case "response.output_text.delta", "response.refusal.delta":
                if let text = event["delta"] as? String { append(text) }
            case "response.output_item.done":
                if let item = event["item"] as? ChatJSON, item["type"] as? String == "function_call",
                   let id = item["call_id"] as? String, let name = item["name"] as? String,
                   let native = converted.names[name], let arguments = item["arguments"] as? String {
                    result.calls.append(ChatToolCall(id: id, name: native, arguments: arguments))
                }
            case "response.completed":
                providerAudit("http-completed", ["request": auditID, "model": (event["response"] as? ChatJSON)?["model"] ?? ""])
                history.capture(event["response"] as? ChatJSON ?? [:])
                finished = true
                let usage = (event["response"] as? ChatJSON)?["usage"] as? ChatJSON
                result.inputTokens = usage?["input_tokens"] as? Int ?? 0
                result.outputTokens = usage?["output_tokens"] as? Int ?? 0
            case "error", "response.failed", "response.incomplete":
                let error = (event["response"] as? ChatJSON)?["error"] as? ChatJSON ?? event["error"] as? ChatJSON ?? event
                if let code = error["code"] as? String, code.hasPrefix("subscription_sharing_usage_") { throw ChatGPTError.usage }
                throw ProviderError.interrupted
            default: break
            }
        } else {
            if event["error"] != nil { throw ChatProviderError.invalidResponse }
            if let usage = event["usage"] as? ChatJSON {
                result.inputTokens = usage["prompt_tokens"] as? Int ?? 0
                result.outputTokens = usage["completion_tokens"] as? Int ?? 0
            }
            guard let choice = (event["choices"] as? [ChatJSON])?.first else { continue }
            if choice["finish_reason"] is String { finished = true }
            let change = choice["delta"] as? ChatJSON
            if let text = change?["content"] as? String { append(text) }
            for part in change?["tool_calls"] as? [ChatJSON] ?? [] {
                guard let index = part["index"] as? Int, (0..<100).contains(index) else { throw ChatProviderError.invalidResponse }
                var call = completionCalls[index, default: ChatToolDelta()]
                if let id = part["id"] as? String { call.id = id }
                if let function = part["function"] as? ChatJSON {
                    call.name += function["name"] as? String ?? ""
                    call.arguments += function["arguments"] as? String ?? ""
                }
                completionCalls[index] = call
            }
        }
    }
    guard finished else { throw ChatProviderError.invalidResponse }
    for index in completionCalls.keys.sorted() {
        guard let call = completionCalls[index], let name = converted.names[call.name], !call.id.isEmpty else {
            throw ChatProviderError.invalidResponse
        }
        result.calls.append(ChatToolCall(id: call.id, name: name, arguments: call.arguments))
    }
    return result
}
