import Foundation

func validProvider(_ provider: ChatJSON) -> Bool {
    guard let id = provider["id"] as? String, UUID(uuidString: id) != nil,
          let name = provider["name"] as? String, !name.isEmpty,
          let api = provider["api"] as? String, ["responses", "chat-completions", "anthropic"].contains(api),
          let base = provider["baseURL"] as? String, (try? ProviderHTTP.base(base)) != nil,
          provider["visibility"] is [String: Bool], provider["autoAdd"] is Bool,
          let catalog = provider["catalog"] as? [ChatJSON] else { return false }
    return catalog.allSatisfy { item in
        guard let id = item["id"] as? String, let name = item["name"] as? String else { return false }
        return !id.isEmpty && !name.isEmpty
    }
}
