import Foundation

enum ChatGPTRegistration {
    static func authorization(client: String?, host: String, state: String, nonce: String, verifier: String,
                              redirect: String, hint: String?) throws -> URL {
        var fields = ["client_id": client ?? "dynamic_agent_client", "ext_agent_host_id": host,
            "response_type": "code", "redirect_uri": redirect, "scope": "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct",
            "resource": ChatGPTHTTP.resource, "state": state, "nonce": nonce, "code_challenge_method": "S256", "code_challenge": oauthChallenge(verifier)]
        if client == nil { fields["agent_name_hint"] = "Dia" }
        else { fields["id_token_hint"] = hint }
        var url = URLComponents(string: ChatGPTHTTP.issuer + "/api/accounts/authorize")!
        url.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let result = url.url else { throw ChatGPTError.callback }; return result
    }
    static func host() -> String {
        let domain = ProcessInfo.processInfo.environment["DIATWEAKS_DOMAIN"] ?? "com.diapatches"
        let defaults = UserDefaults(suiteName: domain)!
        if let host = defaults.string(forKey: "chatGPTAgentHost") { return host }
        let host = "urn:uuid:" + UUID().uuidString.lowercased()
        defaults.set(host, forKey: "chatGPTAgentHost")
        return host
    }
    static func retainClient(id: String, client: String) throws -> ChatJSON {
        ProviderStore.lock.lock(); defer { ProviderStore.lock.unlock() }
        var values = ProviderStore.accounts()
        let index = values.firstIndex { $0["id"] as? String == id }
        var profile = index.map { values[$0] } ?? ["id": id, "name": "ChatGPT", "api": "chatgpt",
            "baseURL": ChatGPTHTTP.resource, "catalog": [ChatJSON](), "visibility": [String: Bool](), "autoAdd": true]
        profile["clientID"] = client
        if let index { values[index] = profile } else { values.append(profile) }
        try ProviderStore.write(values)
        return profile
    }
    static func save(profile: ChatJSON, credentials: ChatJSON) throws {
        guard let id = profile["id"] as? String else { throw ChatGPTError.identity }
        ProviderStore.lock.lock(); defer { ProviderStore.lock.unlock() }
        let old = try ProviderSecrets.read(id)
        let data = try JSONSerialization.data(withJSONObject: credentials)
        try ProviderSecrets.write(id, String(decoding: data, as: UTF8.self))
        do {
            var accounts = ProviderStore.accounts().filter { $0["id"] as? String != id }
            accounts.append(profile)
            try ProviderStore.write(accounts)
        } catch { try? ProviderSecrets.write(id, old); throw error }
        ProviderStore.changed()
    }
    static func credentials(_ id: String) throws -> ChatJSON {
        guard let value = try ProviderSecrets.read(id), let data = value.data(using: .utf8),
              let record = try JSONSerialization.jsonObject(with: data) as? ChatJSON else { throw ChatGPTError.reauthorize }
        return record
    }
}
