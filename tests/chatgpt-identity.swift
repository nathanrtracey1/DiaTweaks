import Foundation
import Security

func testChatGPTIdentity() throws {
    let privateKey = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048] as CFDictionary, nil)!
    let publicKey = SecKeyCopyPublicKey(privateKey)!
    let der = SecKeyCopyExternalRepresentation(publicKey, nil)! as Data
    func contents(_ bytes: Data, _ offset: inout Int) -> Data {
        offset += 1
        var length = Int(bytes[offset]); offset += 1
        if length & 128 != 0 {
            let count = length & 127; length = 0
            for _ in 0..<count { length = length * 256 + Int(bytes[offset]); offset += 1 }
        }
        let value = bytes.subdata(in: offset..<offset+length); offset += length; return value
    }
    var offset = 0
    let sequence = contents(der, &offset)
    offset = 0
    var modulus = contents(sequence, &offset)
    if modulus.first == 0 { modulus.removeFirst() }
    let exponent = contents(sequence, &offset)
    let keys: [ChatJSON] = [["kid": "test", "kty": "RSA", "n": oauthBase64(modulus), "e": oauthBase64(exponent)]]
    func token(_ claims: ChatJSON) throws -> String {
        let header = oauthBase64(try JSONSerialization.data(withJSONObject: ["alg": "RS256", "kid": "test"]))
        let body = oauthBase64(try JSONSerialization.data(withJSONObject: claims))
        let message = header + "." + body
        let signature = SecKeyCreateSignature(privateKey, .rsaSignatureMessagePKCS1v15SHA256, Data(message.utf8) as CFData, nil)! as Data
        return message + "." + oauthBase64(signature)
    }
    var claims: ChatJSON = ["iss": ChatGPTHTTP.issuer, "sub": "fixture-user", "aud": "fixture-client",
        "exp": Date().timeIntervalSince1970 + 600, "nonce": "fixture-nonce"]
    let valid = try token(claims)
    _ = try ChatGPTIdentity.validate(valid, client: "fixture-client", nonce: "fixture-nonce", keys: keys)
    for (client, nonce) in [("wrong-client", "fixture-nonce"), ("fixture-client", "wrong-nonce")] {
        do { _ = try ChatGPTIdentity.validate(valid, client: client, nonce: nonce, keys: keys); preconditionFailure("invalid identity accepted") } catch {}
    }
    claims["exp"] = 0
    do { _ = try ChatGPTIdentity.validate(token(claims), client: "fixture-client", nonce: "fixture-nonce", keys: keys); preconditionFailure("expiry ignored") } catch {}
    do { _ = try ChatGPTIdentity.validate(valid + "a", client: "fixture-client", nonce: "fixture-nonce", keys: keys); preconditionFailure("signature ignored") } catch {}
    let request = try ChatGPTRegistration.authorization(client: nil, host: "urn:uuid:fixture", state: "state", nonce: "nonce",
        verifier: "verifier", redirect: "http://127.0.0.1:1234/auth/callback", hint: nil)
    let query = Dictionary(uniqueKeysWithValues: URLComponents(url: request, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
    precondition(query["client_id"] == "dynamic_agent_client" && query["agent_name_hint"] == "Dia")
    precondition(query["code_challenge"] == oauthChallenge("verifier") && query["code_challenge_method"] == "S256")
    let sanitized = chatGPTRequest(["max_output_tokens": 100, "temperature": 0.5, "tools": [["type": "function", "name": "Read"]]])
    precondition(sanitized["max_output_tokens"] == nil && sanitized["temperature"] == nil)
    precondition((sanitized["tools"] as? [ChatJSON])?.first?["type"] as? String == "namespace")
    print("PASS ChatGPT signatures, audience, nonce, expiry, registration and request restrictions")
}
