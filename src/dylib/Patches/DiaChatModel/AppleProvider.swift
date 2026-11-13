import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleProvider {
    static var available: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *), case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }
    static func catalog() throws -> [ChatJSON] {
        guard available else { throw ProviderError.appleUnavailable }
        return [["id": "on-device", "name": "Apple Intelligence"]]
    }
}

extension ChatProviders {
    @objc static func ensureApple() {
        guard AppleProvider.available else { return }
        ProviderStore.lock.lock(); defer { ProviderStore.lock.unlock() }
        var accounts = ProviderStore.accounts()
        guard !accounts.contains(where: { $0["api"] as? String == "apple" }) else { return }
        var provider: ChatJSON = ["id": UUID().uuidString, "api": "apple", "name": "Apple Intelligence", "baseURL": "", "autoAdd": true]
        ProviderStore.merge((try? AppleProvider.catalog()) ?? [], into: &provider)
        accounts.append(provider)
        do { try ProviderStore.write(accounts); ProviderStore.changed() } catch { }
    }
}

func runAppleChat(_ body: ChatJSON, delta: @escaping (String) -> Void) async throws -> ChatProviderResult {
    #if canImport(FoundationModels)
    if #available(macOS 26, *), AppleProvider.available {
        let context = try await AppleContext(body)
        let tools = body["tools"] as? [ChatJSON] ?? []
        let forced = (body["tool_choice"] as? ChatJSON).flatMap { choice -> ChatJSON? in
            guard choice["type"] as? String == "tool" else { return nil }
            return tools.first { $0["name"] as? String == choice["name"] as? String }
        }
        let selected: ChatJSON?
        if let forced { selected = forced }
        else { selected = try await appleTool(context: context, tools: tools) }
        if let tool = selected {
            guard let schema = tool["input_schema"] as? ChatJSON, let name = tool["name"] as? String else { throw ProviderError.unsupported }
            let parameters = try GenerationSchema(root: appleSchema(schema, name: "Arguments"), dependencies: [])
            try await context.check(schema: parameters)
            let session = LanguageModelSession(instructions: context.instructions)
            let response = try await session.respond(to: "Generate arguments for \(name).\n\(context.prompt)", schema: parameters)
            return ChatProviderResult(calls: [ChatToolCall(id: "dt_" + UUID().uuidString, name: name, arguments: response.content.jsonString)])
        }
        try await context.check()
        let session = LanguageModelSession(instructions: context.instructions)
        var result = ChatProviderResult()
        for try await snapshot in session.streamResponse(to: context.prompt) {
            try Task.checkCancellation()
            guard snapshot.content.hasPrefix(result.text) else { throw ProviderError.invalidResponse }
            delta(String(snapshot.content.dropFirst(result.text.count)))
            result.text = snapshot.content
        }
        return result
    }
    #endif
    throw ProviderError.appleUnavailable
}
