import Foundation

extension OpenAIChatRequest {
    static func messages(_ messages: [ChatJSON], aliases: [String: String], responses: Bool) throws -> [ChatJSON] {
        var input: [ChatJSON] = []
        for message in messages {
            guard let role = message["role"] as? String, ["user", "assistant"].contains(role) else {
                throw ChatProviderError.invalidRequest
            }
            if let text = message["content"] as? String {
                input.append(["role": role, "content": text])
                continue
            }
            var content: [ChatJSON] = []
            var calls: [ChatJSON] = []
            func flush() {
                if responses {
                    if !content.isEmpty { input.append(["role": role, "content": content]) }
                    input.append(contentsOf: calls)
                } else if !content.isEmpty || !calls.isEmpty {
                    var value: ChatJSON = ["role": role, "content": content]
                    if !calls.isEmpty { value["tool_calls"] = calls }
                    input.append(value)
                }
                content.removeAll()
                calls.removeAll()
            }
            for block in message["content"] as? [ChatJSON] ?? [] {
                switch block["type"] as? String {
                case "text":
                    if let text = block["text"] as? String {
                        content.append(["type": responses ? (role == "assistant" ? "output_text" : "input_text") : "text", "text": text])
                    }
                case "image":
                    guard let source = block["source"] as? ChatJSON,
                          let type = source["media_type"] as? String, ["image/jpeg", "image/png", "image/webp", "image/gif"].contains(type),
                          let data = source["data"] as? String, source["type"] as? String == "base64" else {
                        throw ChatProviderError.incompatibleContent
                    }
                    let url = "data:\(type);base64,\(data)"
                    content.append(responses ? ["type": "input_image", "image_url": url] : ["type": "image_url", "image_url": ["url": url]])
                case "tool_use":
                    guard let id = block["id"] as? String, let name = block["name"] as? String else { throw ChatProviderError.invalidRequest }
                    let data = try JSONSerialization.data(withJSONObject: block["input"] as? ChatJSON ?? [:])
                    let arguments = String(decoding: data, as: UTF8.self)
                    let alias = aliases[name] ?? Self.alias(name)
                    if responses {
                        calls.append(["type": "function_call", "call_id": id, "name": alias, "arguments": arguments])
                    } else {
                        calls.append(["type": "function", "id": id, "function": ["name": alias, "arguments": arguments]])
                    }
                case "tool_result":
                    guard let id = block["tool_use_id"] as? String else { throw ChatProviderError.invalidRequest }
                    flush()
                    let output = Self.text(block["content"])
                    if responses { input.append(["type": "function_call_output", "call_id": id, "output": output]) }
                    else { input.append(["role": "tool", "tool_call_id": id, "content": output]) }
                case "thinking", "redacted_thinking", "server_tool_use", "web_search_tool_result":
                    continue
                default:
                    throw ChatProviderError.incompatibleContent
                }
            }
            flush()
        }
        return input
    }
}
