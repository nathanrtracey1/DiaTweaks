import Foundation

enum ProviderSecrets {
    static var values: [String: String] = [:]
    static var fail = false
    static var reads = 0
    static func available(_ id: String) -> Bool { !fail && values[id] != nil }
    static func read(_ id: String) throws -> String? {
        reads += 1
        if fail { throw ProviderError.keychain(-25308) }
        return values[id]
    }
    static func write(_ id: String, _ key: String?) throws {
        if fail { throw ProviderError.keychain(-25308) }
        values[id] = key
    }
}
