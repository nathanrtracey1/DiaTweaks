import Foundation

// Reuse a successfully unlocked credential for this process only. Never persist this cache.
enum ProviderSecretsCache {
    private static let lock = NSRecursiveLock()
    private static var loaded = Set<String>()
    private static var values: [String: String] = [:]

    static func read(_ id: String, load: () throws -> String?) throws -> String? {
        lock.lock(); defer { lock.unlock() }
        if loaded.contains(id) { return values[id] }
        let value = try load()
        values[id] = value; loaded.insert(id)
        return value
    }
    static func write(_ id: String, value: String?, save: () throws -> Void) throws {
        lock.lock(); defer { lock.unlock() }
        try save()
        values[id] = value; loaded.insert(id)
    }
    static func available(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return values[id] != nil
    }
}
