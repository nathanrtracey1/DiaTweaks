import Foundation
import CryptoKit
import Security

func oauthBase64(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
func oauthData(_ value: String) throws -> Data {
    var text = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    text += String(repeating: "=", count: (4 - text.count % 4) % 4)
    guard let data = Data(base64Encoded: text) else { throw ChatGPTError.identity }
    return data
}
func oauthRandom() throws -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw ChatGPTError.identity }
    return oauthBase64(Data(bytes))
}
func oauthChallenge(_ verifier: String) -> String { oauthBase64(Data(SHA256.hash(data: Data(verifier.utf8)))) }

private func der(_ tag: UInt8, _ content: Data) -> Data {
    var length = content.count, bytes: [UInt8] = []
    repeat { bytes.insert(UInt8(length & 255), at: 0); length >>= 8 } while length > 0
    let prefix = content.count < 128 ? [UInt8(content.count)] : [UInt8(128 + bytes.count)] + bytes
    return Data([tag] + prefix) + content
}
func oauthRSAKey(_ jwk: ChatJSON) throws -> SecKey {
    guard jwk["kty"] as? String == "RSA", let n = jwk["n"] as? String, let e = jwk["e"] as? String else { throw ChatGPTError.identity }
    func integer(_ value: String) throws -> Data {
        var data = try oauthData(value)
        if let first = data.first, first & 128 != 0 { data.insert(0, at: 0) }
        return der(2, data)
    }
    let encoded = try der(48, integer(n) + integer(e))
    guard let key = SecKeyCreateWithData(encoded as CFData, [kSecAttrKeyType: kSecAttrKeyTypeRSA,
        kSecAttrKeyClass: kSecAttrKeyClassPublic] as CFDictionary, nil) else { throw ChatGPTError.identity }
    return key
}
