import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26, *)
struct AppleContext {
    let budget = AppleBudget()
    let instructions: String
    let prompt: String
    init(_ body: ChatJSON, instructions override: String? = nil) async throws {
        instructions = override ?? AppleInput.instructions
        let messages = try (body["messages"] as? [ChatJSON] ?? []).map(AppleTurn.init)
        guard let current = messages.lastIndex(where: { $0.request }) else { throw ProviderError.unsupported }
        let pageBudget = AppleExcerpt.capacity / 3
        var recent: [String] = []
        for turn in messages[current...] {
            var text = try await AppleExcerpt.pages(turn.text, tokens: pageBudget)
            if turn.result { text = try await AppleExcerpt.fit(text, tokens: pageBudget, label: "Tool result") }
            recent.append(turn.role + ":\n" + text)
        }
        let earlier = messages[..<current].map { $0.role + ": " + $0.text }.joined(separator: "\n")
        let history = try await AppleExcerpt.fit(String(earlier.suffix(6000)), tokens: AppleExcerpt.capacity / 8, label: "Earlier conversation")
        prompt = (history.isEmpty ? "" : "Earlier conversation excerpt (background):\n" + history + "\n\n") +
            "Current request and subsequent tool results:\n" + recent.joined(separator: "\n\n")
        try await check()
        providerAudit("apple-context-ready", ["input_tokens": try await AppleExcerpt.count(prompt), "capacity": AppleExcerpt.capacity])
    }
    func check(schema: GenerationSchema? = nil, extra: String = "") async throws {
        if #available(macOS 26.4, *) {
            let model = SystemLanguageModel.default
            let instructionsCount = try await model.tokenCount(for: Instructions(instructions))
            let promptCount = try await model.tokenCount(for: Prompt(prompt + extra))
            let schemaCount = try await schema.mapAsync { try await model.tokenCount(for: $0) } ?? 0
            guard instructionsCount + promptCount + schemaCount + 1024 < model.contextSize else { throw ProviderError.appleContext }
        } else if instructions.utf8.count + prompt.utf8.count + extra.utf8.count > 3000 { throw ProviderError.appleContext }
    }
}

private struct AppleTurn {
    let role: String
    let text: String
    let request: Bool
    let result: Bool
    init(_ message: ChatJSON) throws {
        role = message["role"] as? String ?? "user"
        guard ["user", "assistant"].contains(role) else { throw ProviderError.unsupported }
        if let content = message["content"] as? String {
            text = AppleInput.clean(content); request = role == "user" && !text.isEmpty; result = false; return
        }
        guard let blocks = message["content"] as? [ChatJSON] else { throw ProviderError.unsupported }
        var parts: [String] = [], hasRequest = false, hasResult = false
        for block in blocks {
            switch block["type"] as? String {
            case "text":
                let content = AppleInput.clean(block["text"] as? String ?? "")
                parts.append(content); hasRequest = hasRequest || (role == "user" && !content.isEmpty)
            case "tool_use":
                parts.append("Tool call: " + String(decoding: try JSONSerialization.data(withJSONObject: block, options: .sortedKeys), as: UTF8.self))
            case "tool_result":
                parts.append("Tool result \(block["tool_use_id"] as? String ?? "")" + ((block["is_error"] as? Bool == true) ? " (failed)" : "") + ":\n" + OpenAIChatRequest.text(block["content"]))
                hasResult = true
            case "thinking", "redacted_thinking": break
            default: throw ProviderError.unsupported
            }
        }
        var seen = Set<String>()
        text = parts.filter { !$0.isEmpty && seen.insert($0).inserted }.joined(separator: "\n")
        request = hasRequest && !hasResult; result = hasResult
    }
}

private extension Optional {
    func mapAsync<T>(_ transform: (Wrapped) async throws -> T) async rethrows -> T? {
        guard let value = self else { return nil }; return try await transform(value)
    }
}
#endif
