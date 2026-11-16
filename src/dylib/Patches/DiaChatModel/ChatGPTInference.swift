import Foundation

func chatGPTRequest(_ input: ChatJSON) -> ChatJSON {
    var body = input
    for name in ["background", "conversation", "max_output_tokens", "max_tool_calls", "metadata", "moderation", "multi_agent",
                 "prompt", "prompt_cache_retention", "safety_identifier", "temperature", "top_logprobs", "top_p", "truncation", "user", "previous_response_id"] {
        body.removeValue(forKey: name)
    }
    if let tools = body["tools"] as? [ChatJSON], !tools.isEmpty {
        body["tools"] = [["type": "namespace", "name": "dia", "description": "Tools executed by Dia with the user’s permissions.", "tools": tools]]
    }
    body["store"] = false; body["stream"] = true
    return body
}

extension ChatGPTAccess {
    static func catalog(_ account: ChatJSON) async throws -> [ChatJSON] {
        let provider = try await provider(account)
        let request = try ProviderHTTP.request(provider, path: "models")
        let session = ProviderHTTP.session(); defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        try ProviderHTTP.check(response)
        guard data.count <= 8 * 1024 * 1024, let value = try JSONSerialization.jsonObject(with: data) as? ChatJSON,
              let models = value["models"] as? [ChatJSON] else { throw ProviderError.invalidResponse }
        return models.compactMap { model in
            guard model["visibility"] as? String == "list", let id = model["slug"] as? String,
                  let name = model["display_name"] as? String else { return nil }
            return ["id": id, "name": name]
        }
    }
}
