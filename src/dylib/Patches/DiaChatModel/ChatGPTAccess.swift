import Foundation

actor ChatGPTAccess {
    static let shared = ChatGPTAccess()
    private var refreshing: [String: Task<ChatJSON, Error>] = [:]
    private var signedOut = Set<String>()
    func connected(_ id: String) { signedOut.remove(id) }
    static func record(_ tokens: ChatJSON, previous: ChatJSON, client: String) throws -> ChatJSON {
        guard let access = tokens["access_token"] as? String, !access.isEmpty,
              (tokens["token_type"] as? String)?.lowercased() == "bearer",
              let duration = tokens["expires_in"] as? Double, duration > 0 else { throw ChatGPTError.identity }
        let scopes = (tokens["scope"] as? String)?.split(separator: " ").map(String.init) ?? previous["scopes"] as? [String] ?? []
        guard scopes.contains("chatgpt.tokens.use.direct") else { throw ChatGPTError.permission }
        var value = previous
        value["access_token"] = access
        value["refresh_token"] = tokens["refresh_token"] ?? previous["refresh_token"]
        value["id_token"] = tokens["id_token"] ?? previous["id_token"]
        value["scopes"] = scopes; value["client_id"] = client
        value["generation"] = previous["generation"] ?? UUID().uuidString
        value["expires_at"] = Date().timeIntervalSince1970 + duration
        return value
    }
    func token(_ id: String, client: String) async throws -> String {
        guard !signedOut.contains(id) else { throw ChatGPTError.reauthorize }
        let record = try ChatGPTRegistration.credentials(id)
        guard record["client_id"] as? String == client else { throw ChatGPTError.identity }
        if (record["expires_at"] as? Double ?? 0) > Date().timeIntervalSince1970 + 60,
           let token = record["access_token"] as? String { return token }
        if let pending = refreshing[id] {
            let value = try await pending.value
            guard !signedOut.contains(id) else { throw ChatGPTError.reauthorize }
            return value["access_token"] as! String
        }
        let task = Task { try await renew(id, record: record, client: client) }
        refreshing[id] = task
        defer { refreshing[id] = nil }
        let value = try await task.value
        guard !signedOut.contains(id) else { throw ChatGPTError.reauthorize }
        return value["access_token"] as! String
    }
    private func renew(_ id: String, record: ChatJSON, client: String) async throws -> ChatJSON {
        guard let refresh = record["refresh_token"] as? String else { throw ChatGPTError.reauthorize }
        let response = try await ChatGPTHTTP.tokens(["grant_type": "refresh_token", "client_id": client,
            "refresh_token": refresh, "resource": ChatGPTHTTP.resource])
        if let token = response["id_token"] as? String {
            let claims = try await ChatGPTIdentity.verify(token, client: client, nonce: nil)
            guard claims["sub"] as? String == ChatProviders.account(id)?["subject"] as? String else { throw ChatGPTError.identity }
        }
        let replacement = try Self.record(response, previous: record, client: client)
        if signedOut.contains(id) { return replacement }
        let current = try ChatGPTRegistration.credentials(id)
        if current["generation"] as? String != record["generation"] as? String { return current }
        try ProviderSecrets.write(id, String(decoding: JSONSerialization.data(withJSONObject: replacement), as: UTF8.self))
        return replacement
    }
    func signOut(_ id: String) async throws {
        signedOut.insert(id)
        if try ProviderSecrets.read(id) == nil { return }
        var problem: Error?
        do {
            let record: ChatJSON
            if let pending = refreshing[id], let refreshed = try? await pending.value { record = refreshed }
            else { record = try ChatGPTRegistration.credentials(id) }
            if let refresh = record["refresh_token"] as? String, let client = record["client_id"] as? String {
                let discovery = try await ChatGPTHTTP.discovery()
                let endpoint = URL(string: discovery["revocation_endpoint"] as! String)!
                do { _ = try await ChatGPTHTTP.json(endpoint, fields: ["token": refresh, "token_type_hint": "refresh_token", "client_id": client]) }
                catch {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    _ = try await ChatGPTHTTP.json(endpoint, fields: ["token": refresh, "token_type_hint": "refresh_token", "client_id": client])
                }
            }
        } catch { problem = ChatGPTError.revocation }
        try ProviderSecrets.write(id, nil)
        if let problem { throw problem }
    }
    static func provider(_ snapshot: ChatJSON) async throws -> ChatJSON {
        guard let id = snapshot["id"] as? String, let client = snapshot["clientID"] as? String else { throw ChatGPTError.reauthorize }
        var provider = snapshot
        provider["credential"] = try await shared.token(id, client: client)
        provider["baseURL"] = ChatGPTHTTP.resource
        return provider
    }
}
