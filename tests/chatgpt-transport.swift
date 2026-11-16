import Foundation

struct ProviderTestTransport { static var protocols: [AnyClass] = [] }
final class OAuthFixture: URLProtocol {
    static let lock = NSLock()
    static var refreshes = 0, revocations = 0
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "auth.openai.com" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let object: ChatJSON
        if path.hasSuffix("openid-configuration") {
            object = ["issuer": ChatGPTHTTP.issuer, "authorization_endpoint": ChatGPTHTTP.issuer + "/api/accounts/authorize",
                "token_endpoint": ChatGPTHTTP.issuer + "/api/accounts/oauth/token", "jwks_uri": ChatGPTHTTP.issuer + "/.well-known/jwks.json",
                "revocation_endpoint": ChatGPTHTTP.issuer + "/api/accounts/oauth/revoke"]
        } else if path.hasSuffix("/token") {
            Self.lock.lock(); Self.refreshes += 1; Self.lock.unlock()
            object = ["access_token": "fixture-replacement", "refresh_token": "fixture-rotated", "token_type": "Bearer", "expires_in": 3600]
        } else if path.hasSuffix("/revoke") {
            Self.lock.lock(); Self.revocations += 1; Self.lock.unlock(); object = [:]
        } else { client?.urlProtocol(self, didFailWithError: ProviderError.invalidResponse); return }
        let data = try! JSONSerialization.data(withJSONObject: object)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

func testChatGPTSessions() async throws {
    ProviderTestTransport.protocols = [OAuthFixture.self]
    defer { ProviderTestTransport.protocols = [] }
    let id = UUID().uuidString
    var profile = try ChatGPTRegistration.retainClient(id: id, client: "fixture-client")
    profile["subject"] = "fixture-user"
    let original: ChatJSON = ["access_token": "fixture-old", "refresh_token": "fixture-refresh", "token_type": "Bearer",
        "expires_in": 1.0, "scope": "openid chatgpt.tokens.use.direct"]
    var record = try ChatGPTAccess.record(original, previous: [:], client: "fixture-client")
    record["expires_at"] = 0
    try ChatGPTRegistration.save(profile: profile, credentials: record)
    let auth = ChatGPTAccess()
    try await withThrowingTaskGroup(of: String.self) { group in
        for _ in 0..<8 { group.addTask { try await auth.token(id, client: "fixture-client") } }
        for try await token in group { precondition(token == "fixture-replacement") }
    }
    precondition(OAuthFixture.refreshes == 1)
    let updated = try ChatGPTRegistration.credentials(id)
    precondition(updated["refresh_token"] as? String == "fixture-rotated")
    try await auth.signOut(id)
    let cleared = try ProviderSecrets.read(id)
    precondition(cleared == nil)
    precondition(ChatProviders.account(id)?["clientID"] as? String == "fixture-client" && OAuthFixture.revocations == 1)
    do { _ = try await auth.token(id, client: "fixture-client"); preconditionFailure("signed-out session used") } catch {}
    var denied = original; denied["scope"] = "openid"
    do { _ = try ChatGPTAccess.record(denied, previous: [:], client: "fixture-client"); preconditionFailure("missing permission accepted") } catch {}
    print("PASS serialized token refresh, rotation, revocation, retained registrations and sign-out")
}
