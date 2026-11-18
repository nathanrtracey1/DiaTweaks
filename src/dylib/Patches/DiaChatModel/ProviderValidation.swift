import Foundation

func validProvider(_ provider: ChatJSON) -> Bool {
    guard let id = provider["id"] as? String, UUID(uuidString: id) != nil,
          let name = provider["name"] as? String, !name.isEmpty,
          let api = provider["api"] as? String, ["responses", "chat-completions", "anthropic", "apple", "chatgpt"].contains(api),
          let base = provider["baseURL"] as? String, api == "apple" || (try? ProviderHTTP.base(base)) != nil,
          provider["visibility"] is [String: Bool], provider["autoAdd"] is Bool,
          let catalog = provider["catalog"] as? [ChatJSON] else { return false }
    if api == "chatgpt", base != ChatGPTHTTP.resource { return false }
    if let preset = provider["preset"], !(preset is String && ProviderBranding.presets.contains(preset as! String)) { return false }
    return catalog.allSatisfy { item in
        guard let id = item["id"] as? String, let name = item["name"] as? String else { return false }
        return !id.isEmpty && !name.isEmpty
    }
}
