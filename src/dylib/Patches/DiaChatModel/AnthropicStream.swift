import Foundation

func streamAnthropic(_ payload: ChatJSON, provider: ChatJSON, chunk: (String) -> Void, calls: (NSArray) -> Void) async throws {
    var body = payload
    body["model"] = provider["model"]
    body["stream"] = true
    var request = try ProviderHTTP.request(provider, path: "messages")
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    let session = ProviderHTTP.session(); defer { session.invalidateAndCancel() }
    let (bytes, response) = try await session.bytes(for: request)
    try ProviderHTTP.check(response)
    var finished = false, size = 0
    var blocks: [Int: ChatJSON] = [:], arguments: [Int: String] = [:]
    for try await line in bytes.lines {
        try Task.checkCancellation()
        size += line.utf8.count
        guard size < 32 * 1024 * 1024 else { throw ProviderError.invalidResponse }
        if line.hasPrefix("data:"), let data = line.dropFirst(5).data(using: .utf8),
           let event = try JSONSerialization.jsonObject(with: data) as? ChatJSON {
            switch event["type"] as? String {
            case "error": throw ProviderError.invalidResponse
            case "content_block_start":
                if let index = event["index"] as? Int, let block = event["content_block"] as? ChatJSON,
                   block["type"] as? String == "tool_use" { blocks[index] = block }
            case "content_block_delta":
                if let index = event["index"] as? Int, let change = event["delta"] as? ChatJSON,
                   let text = change["partial_json"] as? String { arguments[index, default: ""] += text }
            case "message_stop":
                var result: [ChatJSON] = []
                for index in blocks.keys.sorted() {
                    var block = blocks[index]!
                    if let text = arguments[index] { block["input"] = try JSONSerialization.jsonObject(with: Data(text.utf8)) }
                    result.append(block)
                }
                calls(result as NSArray); finished = true
            default: break
            }
        }
        chunk(line + "\n")
        if line.hasPrefix("data:") { chunk("\n") }
    }
    guard finished else { throw ProviderError.interrupted }
}
