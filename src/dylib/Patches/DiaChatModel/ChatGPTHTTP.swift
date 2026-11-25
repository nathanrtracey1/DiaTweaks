import Foundation

enum ChatGPTError: LocalizedError {
    case cancelled, callback, identity, permission, reauthorize, usage, revocation
    var errorDescription: String? {
        switch self {
        case .cancelled: return "ChatGPT sign-in was cancelled."
        case .callback: return "ChatGPT returned an invalid sign-in callback. Please try again."
        case .identity: return "ChatGPT’s identity could not be verified. Please sign in again."
        case .permission: return "ChatGPT plan usage was not enabled. Continue with ChatGPT to authorize it."
        case .reauthorize: return "Your ChatGPT session expired or was revoked. Continue with ChatGPT to reconnect."
        case .usage: return "ChatGPT usage limit reached. Manage usage at chatgpt.com/settings/usage."
        case .revocation: return "Signed out locally. Remote revocation was not confirmed. Disconnect this app in ChatGPT Settings."
        }
    }
}

enum ChatGPTHTTP {
    static let issuer = "https://auth.openai.com"
    static let resource = "https://api.openai.com/v1"
    static func form(_ fields: [String: String]) -> Data {
        var parts = URLComponents()
        parts.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return Data((parts.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B").utf8)
    }
    static func json(_ url: URL, fields: [String: String]? = nil) async throws -> ChatJSON {
        var request = URLRequest(url: url, timeoutInterval: 30)
        if let fields {
            request.httpMethod = "POST"; request.httpBody = form(fields)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        let session = ProviderHTTP.session(); defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard data.count <= 1024 * 1024 else { throw ProviderError.invalidResponse }
        let object = data.isEmpty ? [:] : try JSONSerialization.jsonObject(with: data) as? ChatJSON ?? [:]
        if object["error"] as? String == "invalid_grant" { throw ChatGPTError.reauthorize }
        try ProviderHTTP.check(response)
        return object
    }
    static func discovery() async throws -> ChatJSON {
        let value = try await json(URL(string: issuer + "/.well-known/openid-configuration")!)
        guard value["issuer"] as? String == issuer else { throw ChatGPTError.identity }
        for key in ["authorization_endpoint", "token_endpoint", "jwks_uri", "revocation_endpoint"] {
            guard let raw = value[key] as? String, let url = URL(string: raw), url.scheme == "https",
                  url.host == "auth.openai.com", url.user == nil, url.password == nil else { throw ChatGPTError.identity }
        }
        return value
    }
    static func tokens(_ fields: [String: String]) async throws -> ChatJSON {
        try await json(URL(string: issuer + "/api/accounts/oauth/token")!, fields: fields)
    }
}
