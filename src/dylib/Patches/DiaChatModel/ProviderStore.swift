import Foundation

enum ProviderStore {
    static let lock = NSRecursiveLock()
    static var loaded: [[String: Any]]?
    static var loadFailed = false
    static var path: URL {
        let support = ProcessInfo.processInfo.environment["DIAPATCH_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DiaPatches")
        return support.appendingPathComponent("chat-model-providers.json")
    }
    static func accounts() -> [ChatJSON] {
        lock.lock(); defer { lock.unlock() }
        if let loaded { return loaded }
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        guard let data = try? Data(contentsOf: path), data.count <= 8 * 1024 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? ChatJSON,
              object["version"] as? Int == 1, let values = object["accounts"] as? [ChatJSON],
              values.allSatisfy(validProvider) else { loadFailed = true; return [] }
        loaded = values.map(ProviderBranding.normalized)
        return loaded ?? []
    }
    static func write(_ values: [ChatJSON]) throws {
        guard !loadFailed else { throw ProviderError.configuration }
        let normalized = values.map(ProviderBranding.normalized)
        let data = try JSONSerialization.data(withJSONObject: ["version": 1, "accounts": normalized], options: .sortedKeys)
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: path, options: .atomic)
        loaded = normalized
    }
    static func change(_ id: String, _ update: (inout ChatJSON) throws -> Void) throws {
        lock.lock(); defer { lock.unlock() }
        var values = accounts()
        guard let index = values.firstIndex(where: { $0["id"] as? String == id }) else { throw ProviderError.removed }
        try update(&values[index])
        try write(values)
    }
    static func changed() {
        DispatchQueue.main.async { NotificationCenter.default.post(name: .init("DPChatProvidersChanged"), object: nil) }
    }
    static func merge(_ catalog: [ChatJSON], into account: inout ChatJSON) {
        var visibility = account["visibility"] as? [String: Bool] ?? [:]
        for model in catalog {
            if let id = model["id"] as? String, visibility[id] == nil { visibility[id] = account["autoAdd"] as? Bool ?? true }
        }
        account["visibility"] = visibility
        account["catalog"] = catalog
        account["refreshed"] = Date().timeIntervalSince1970
    }
}

enum ProviderError: LocalizedError {
    case removed, invalidURL, keychain(Int32), authentication, rateLimited, unsupported, interrupted, invalidResponse, configuration, appleUnavailable, appleContext, appleTimeout, appleFileURL
    var errorDescription: String? {
        switch self {
        case .removed: return "This provider account is no longer available."
        case .invalidURL: return "Use an HTTPS API base URL, or HTTP for a loopback server."
        case .keychain(let code): return "Keychain could not access this account (\(code))."
        case .authentication: return "Authentication failed. Check this provider’s credentials."
        case .rateLimited: return "The provider’s usage or rate limit was reached."
        case .unsupported: return "The selected model cannot handle this content or tool schema."
        case .interrupted: return "The model response was interrupted before completion."
        case .invalidResponse: return "The provider returned an invalid response."
        case .configuration: return "The saved provider configuration could not be read. Restore it before saving changes."
        case .appleUnavailable: return "Apple Intelligence is unavailable. Check that it is enabled and its model has finished downloading."
        case .appleTimeout: return "Apple Intelligence took too long to respond. Try a shorter chat, or choose another model."
        case .appleContext: return "This chat or tool result exceeds the on-device model’s context capacity."
        case .appleFileURL: return "The model selected a file tool for a web address. Use the page or web tool instead."
        }
    }
}
