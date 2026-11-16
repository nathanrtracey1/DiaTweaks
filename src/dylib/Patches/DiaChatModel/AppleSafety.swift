import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

func runAppleSafety(_ body: ChatJSON, delta: @escaping (String) -> Void) async throws -> ChatProviderResult {
    try await withProviderDeadline(seconds: 40) {
        #if canImport(FoundationModels)
        if #available(macOS 26, *), AppleProvider.available {
            let context = try await AppleContext(body, instructions: OpenAIChatRequest.text(body["system"]))
            let schema = try GenerationSchema(root: DynamicGenerationSchema(name: "SafetyDecision", properties: [
                .init(name: "decision", schema: .init(name: "Decision", anyOf: ["allow", "deny", "ask"])),
                .init(name: "reason", schema: .init(type: String.self))]), dependencies: [])
            try await context.check(schema: schema)
            let session = LanguageModelSession(instructions: context.instructions)
            let response = try await session.respond(to: context.prompt, schema: schema,
                options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 256))
            try Task.checkCancellation()
            let text = response.content.jsonString
            delta(text); return ChatProviderResult(text: text)
        }
        #endif
        throw ProviderError.appleUnavailable
    }
}
