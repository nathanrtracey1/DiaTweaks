import Foundation
import Security

enum ChatGPTIdentity {
    static func validate(_ token: String, client: String, nonce: String?, keys: [ChatJSON], now: Date = Date()) throws -> ChatJSON {
        let parts = token.components(separatedBy: ".")
        guard token.utf8.count <= 32768, parts.count == 3,
              let header = try JSONSerialization.jsonObject(with: oauthData(parts[0])) as? ChatJSON,
              header["alg"] as? String == "RS256", let kid = header["kid"] as? String,
              let jwk = keys.first(where: { $0["kid"] as? String == kid }),
              jwk["use"] as? String == nil || jwk["use"] as? String == "sig" else { throw ChatGPTError.identity }
        let key = try oauthRSAKey(jwk)
        let message = Data((parts[0] + "." + parts[1]).utf8)
        guard SecKeyVerifySignature(key, .rsaSignatureMessagePKCS1v15SHA256, message as CFData, try oauthData(parts[2]) as CFData, nil),
              let claims = try JSONSerialization.jsonObject(with: oauthData(parts[1])) as? ChatJSON,
              claims["iss"] as? String == ChatGPTHTTP.issuer,
              let expiry = claims["exp"] as? Double, expiry > now.timeIntervalSince1970,
              let subject = claims["sub"] as? String, !subject.isEmpty else { throw ChatGPTError.identity }
        let audience = (claims["aud"] as? [String]) ?? (claims["aud"] as? String).map { [$0] } ?? []
        guard audience.contains(client), (claims["iat"] as? Double ?? 0) <= now.timeIntervalSince1970 + 60,
              nonce == nil || claims["nonce"] as? String == nonce else { throw ChatGPTError.identity }
        if audience.count > 1 && claims["azp"] as? String != client { throw ChatGPTError.identity }
        return claims
    }
    static func verify(_ token: String, client: String, nonce: String?) async throws -> ChatJSON {
        let discovery = try await ChatGPTHTTP.discovery()
        let jwks = try await ChatGPTHTTP.json(URL(string: discovery["jwks_uri"] as! String)!)
        return try validate(token, client: client, nonce: nonce, keys: jwks["keys"] as? [ChatJSON] ?? [])
    }
}
