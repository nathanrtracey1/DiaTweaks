import Foundation

enum ProviderBranding {
    static let presets = ["openai", "anthropic", "google", "custom"]
    static func preset(_ account: ChatJSON) -> String {
        if let preset = account["preset"] as? String, presets.contains(preset) { return preset }
        return brand(account)
    }
    static func brand(_ account: ChatJSON) -> String {
        let api = account["api"] as? String ?? ""
        if api == "apple" || api == "chatgpt" { return api }
        guard let host = URL(string: account["baseURL"] as? String ?? "")?.host?.lowercased() else { return "custom" }
        for (domain, brand) in [("openai.com", "openai"), ("anthropic.com", "anthropic"), ("googleapis.com", "google")] {
            if host == domain || host.hasSuffix("." + domain) { return brand }
        }
        return "custom"
    }
    static func normalized(_ account: ChatJSON) -> ChatJSON {
        var value = account
        if ["responses", "chat-completions", "anthropic"].contains(account["api"] as? String ?? "") {
            value["preset"] = preset(account)
        }
        if account["api"] as? String == "chatgpt", let client = account["clientID"] as? String, !client.isEmpty,
           let name = account["name"] as? String, name.hasPrefix("ChatGPT · ") {
            let suffix = " · " + client.suffix(6)
            if name.hasSuffix(suffix) {
                let clean = String(name.dropLast(suffix.count))
                let identity = clean.dropFirst("ChatGPT · ".count)
                if identity.contains("@") || identity == "Account" { value["name"] = identity == "Account" ? "ChatGPT" : clean }
            }
        }
        return value
    }
}

extension ChatProviders {
    @objc(brand:) static func brand(_ account: NSDictionary) -> String { ProviderBranding.brand(account as? ChatJSON ?? [:]) }
    @objc(preset:) static func preset(_ account: NSDictionary) -> String { ProviderBranding.preset(account as? ChatJSON ?? [:]) }
}
