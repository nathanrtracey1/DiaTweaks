import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26, *)
func appleTool(context: AppleContext, tools: [ChatJSON]) async throws -> ChatJSON? {
    guard !tools.isEmpty else { return nil }
    var candidates: [ChatJSON] = []
    for start in stride(from: 0, to: tools.count, by: 12) {
        let group = Array(tools[start..<min(start + 12, tools.count)])
        if let tool = try await selectAppleTool(context, group) { candidates.append(tool) }
    }
    while candidates.count > 12 {
        var reduced: [ChatJSON] = []
        for start in stride(from: 0, to: candidates.count, by: 12) {
            if let tool = try await selectAppleTool(context, Array(candidates[start..<min(start + 12, candidates.count)])) { reduced.append(tool) }
        }
        candidates = reduced
    }
    return candidates.count == 1 ? candidates[0] : try await selectAppleTool(context, candidates)
}

@available(macOS 26, *)
private func selectAppleTool(_ context: AppleContext, _ tools: [ChatJSON]) async throws -> ChatJSON? {
    if tools.isEmpty { return nil }
    let names = tools.compactMap { $0["name"] as? String }
    let schema = try GenerationSchema(root: DynamicGenerationSchema(name: "ToolChoice", properties: [
        .init(name: "tool", description: "Choose the next tool, or none when ready to answer using the available results.",
              schema: .init(name: "ToolName", anyOf: ["none"] + names))]), dependencies: [])
    let descriptions = tools.map { "\($0["name"] as? String ?? ""): \(String(($0["description"] as? String ?? "").prefix(140)))" }.joined(separator: "\n")
    try await context.check(schema: schema, extra: descriptions)
    let session = LanguageModelSession(instructions: context.instructions)
    let response = try await session.respond(to: context.prompt + "\nAvailable tools:\n" + descriptions, schema: schema)
    let choice = try response.content.value(String.self, forProperty: "tool")
    return tools.first { $0["name"] as? String == choice }
}

@available(macOS 26, *)
func appleSchema(_ schema: ChatJSON, name: String, depth: Int = 0) throws -> DynamicGenerationSchema {
    guard depth < 12 else { throw ProviderError.unsupported }
    if let choices = schema["enum"] as? [String], !choices.isEmpty { return .init(name: name, anyOf: choices) }
    switch schema["type"] as? String {
    case "object":
        let required = schema["required"] as? [String] ?? []
        let properties = try (schema["properties"] as? [String: ChatJSON] ?? [:]).sorted { $0.key < $1.key }.map { key, value in
            DynamicGenerationSchema.Property(name: key, description: value["description"] as? String,
                schema: try appleSchema(value, name: name + "_" + key, depth: depth + 1), isOptional: !required.contains(key))
        }
        return .init(name: name, properties: properties)
    case "array":
        guard let items = schema["items"] as? ChatJSON else { throw ProviderError.unsupported }
        return .init(arrayOf: try appleSchema(items, name: name + "_item", depth: depth + 1),
            minimumElements: schema["minItems"] as? Int, maximumElements: schema["maxItems"] as? Int)
    case "string": return .init(type: String.self)
    case "boolean": return .init(type: Bool.self)
    case "integer": return .init(type: Int.self)
    case "number": return .init(type: Double.self)
    default: throw ProviderError.unsupported
    }
}
#endif
