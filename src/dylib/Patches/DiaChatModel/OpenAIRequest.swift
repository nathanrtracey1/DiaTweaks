import Foundation
import CryptoKit

typealias ChatJSON = [String: Any]

struct ChatToolCall {
    let id: String
    let name: String
    let arguments: String
}

enum ChatProviderError: Error {
    case invalidRequest, incompatibleContent, invalidResponse, unavailable, missingCredential
}

struct OpenAIChatRequest {
    let body: ChatJSON
    let names: [String: String]

    init(_ payload: ChatJSON, model: String, responses: Bool) throws {
        guard let messages = payload["messages"] as? [ChatJSON] else { throw ChatProviderError.invalidRequest }
        var body: ChatJSON = ["model": model, "stream": true]
        if let limit = payload["max_tokens"] as? Int, limit > 0 {
            body[responses ? "max_output_tokens" : "max_completion_tokens"] = limit
        }
        var input: [ChatJSON] = []
        let system = Self.text(payload["system"])
        if !system.isEmpty {
            if responses { body["instructions"] = system }
            else { input.append(["role": "system", "content": system]) }
        }
        var names: [String: String] = [:]
        var aliases: [String: String] = [:]
        var tools: [ChatJSON] = []
        for tool in payload["tools"] as? [ChatJSON] ?? [] {
            guard let name = tool["name"] as? String, let schema = tool["input_schema"] as? ChatJSON else { continue }
            let alias = Self.alias(name)
            names[alias] = name
            aliases[name] = alias
            var function: ChatJSON = ["name": alias, "parameters": schema, "strict": false]
            if let description = tool["description"] as? String { function["description"] = description }
            if responses {
                function["type"] = "function"
                tools.append(function)
            } else {
                tools.append(["type": "function", "function": function])
            }
        }
        input.append(contentsOf: try Self.messages(messages, aliases: aliases, responses: responses))
        if responses { body["store"] = false }
        body[responses ? "input" : "messages"] = input
        if !tools.isEmpty { body["tools"] = tools }
        self.body = body
        self.names = names
    }

    static func alias(_ name: String) -> String {
        if name.range(of: "^[a-zA-Z0-9_-]{1,64}$", options: .regularExpression) != nil,
           !name.hasPrefix("dt_hash_") { return name }
        let hash = SHA256.hash(data: Data(name.utf8))
        return "dt_hash_" + hash.prefix(20).map { String(format: "%02x", $0) }.joined()
    }

    static func text(_ value: Any?) -> String {
        if let value = value as? String { return value }
        return (value as? [ChatJSON] ?? []).compactMap { $0["text"] as? String }.joined(separator: "\n")
    }
}
