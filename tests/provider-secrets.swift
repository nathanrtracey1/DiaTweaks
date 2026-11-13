import Foundation

enum ProviderSecrets {
    static var values: [String: String] = [:]
    static var fail = false
    static func read(_ id: String) throws -> String? {
        if fail { throw ProviderError.keychain(-25308) }
        return values[id]
    }
    static func write(_ id: String, _ key: String?) throws {
        if fail { throw ProviderError.keychain(-25308) }
        values[id] = key
    }
}
