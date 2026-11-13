import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

func testAppleChat() async throws {
    #if canImport(FoundationModels)
    if #available(macOS 26, *) {
        let schema: ChatJSON = ["type": "object", "properties": ["query": ["type": "string"]], "required": ["query"]]
        _ = try GenerationSchema(root: appleSchema(schema, name: "Fixture"), dependencies: [])
        do { _ = try appleSchema(["type": "unknown"], name: "Bad"); preconditionFailure("unsupported schema accepted") } catch {}
        guard AppleProvider.available else { print("SKIP live Apple generation: on-device model unavailable"); return }
        let tool: ChatJSON = ["name": "lookup", "description": "Look up the fixture result for a query.", "input_schema": schema]
        let body: ChatJSON = ["system": "Use provided tools when asked. Answer from tool results when present.",
            "messages": [["role": "user", "content": "Call lookup with query compatibility."]], "tools": [tool],
            "tool_choice": ["type": "tool", "name": "lookup"]]
        let first = try await runAppleChat(body) { _ in }
        precondition(first.calls.count == 1 && first.calls[0].name == "lookup")
        let input = try JSONSerialization.jsonObject(with: Data(first.calls[0].arguments.utf8)) as! ChatJSON
        precondition(input["query"] is String)
        let next: ChatJSON = ["messages": [["role": "user", "content": "Read the tool result and say its value."],
            ["role": "assistant", "content": [["type": "tool_use", "id": first.calls[0].id, "name": "lookup", "input": input]]],
            ["role": "user", "content": [["type": "tool_result", "tool_use_id": first.calls[0].id, "content": "The value is APPLE-FIXTURE-OK"]]]]]
        var text = ""
        let result = try await runAppleChat(next) { text += $0 }
        precondition(!result.text.isEmpty && result.text == text)
        let enormous: ChatJSON = ["messages": [["role": "user", "content": String(repeating: "long context ", count: 8000)]]]
        do { _ = try await runAppleChat(enormous) { _ in }; preconditionFailure("context limit ignored") } catch {}
        print("PASS live Apple argument generation, tool-result continuation, streaming and context limits")
    }
    #endif
}
