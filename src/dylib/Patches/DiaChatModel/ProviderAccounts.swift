import Foundation

@objc(DPChatProviders) final class ChatProviders: NSObject {
    @objc static func accounts() -> NSArray { ProviderStore.accounts() as NSArray }
    @objc static func account(_ id: String) -> NSDictionary? {
        ProviderStore.accounts().first { $0["id"] as? String == id } as NSDictionary?
    }
    @objc(save:key:) static func save(_ input: NSDictionary, key: String?) -> String? {
        ProviderStore.lock.lock(); defer { ProviderStore.lock.unlock() }
        do {
            guard let id = input["id"] as? String, UUID(uuidString: id) != nil,
                  let name = input["name"] as? String, !name.isEmpty,
                  let api = input["api"] as? String, ["responses", "chat-completions", "anthropic"].contains(api),
                  let base = input["baseURL"] as? String else { throw ProviderError.invalidURL }
            _ = try ProviderHTTP.base(base)
            if let preset = input["preset"], !(preset is String && ProviderBranding.presets.contains(preset as! String)) { throw ProviderError.configuration }
            var values = ProviderStore.accounts()
            let index = values.firstIndex { $0["id"] as? String == id }
            var provider = index.map { values[$0] } ?? ["id": id, "autoAdd": true, "visibility": [String: Bool](), "catalog": [ChatJSON]()]
            let oldKey = try ProviderSecrets.read(id)
            if let key { try ProviderSecrets.write(id, key) }
            let connectionChanged = provider["baseURL"] as? String != base || provider["api"] as? String != api || key != nil
            provider["name"] = name; provider["api"] = api; provider["baseURL"] = base
            if let preset = input["preset"] { provider["preset"] = preset }
            provider["revision"] = (provider["revision"] as? Int ?? 0) + 1
            if connectionChanged { provider["refreshed"] = 0 }
            if let index { values[index] = provider } else { values.append(provider) }
            do { try ProviderStore.write(values) }
            catch { if key != nil { try? ProviderSecrets.write(id, oldKey) }; throw error }
            ProviderStore.changed()
            refresh(id, force: connectionChanged) { _ in }
            return nil
        } catch { return providerMessage(error) }
    }
    @objc static func snapshot(_ id: String) -> NSDictionary {
        guard var value = account(id) as? ChatJSON else { return ["error": ProviderError.removed.localizedDescription] }
        if value["api"] as? String == "apple" { return value as NSDictionary }
        do { value["credential"] = try ProviderSecrets.read(id) }
        catch { value["error"] = providerMessage(error) }
        return value as NSDictionary
    }
    @objc static func credentialAvailable(_ id: String) -> Bool { ProviderSecrets.available(id) }
    @objc static func remove(_ id: String) -> String? {
        ProviderStore.lock.lock(); defer { ProviderStore.lock.unlock() }
        do {
            let key = try ProviderSecrets.read(id)
            try ProviderSecrets.write(id, nil)
            do { try ProviderStore.write(ProviderStore.accounts().filter { $0["id"] as? String != id }) }
            catch { try? ProviderSecrets.write(id, key); throw error }
            ProviderStore.changed(); return nil
        } catch { return providerMessage(error) }
    }
}

func providerMessage(_ error: Error) -> String {
    if let error = error as? ProviderError { return error.localizedDescription }
    if let error = error as? ChatGPTError { return error.localizedDescription }
    if error is CancellationError { return "The model request was cancelled." }
    if let error = error as? ChatProviderError {
        switch error {
        case .incompatibleContent: return ProviderError.unsupported.localizedDescription
        default: return ProviderError.invalidResponse.localizedDescription
        }
    }
    if error is URLError { return "Could not reach the provider. Check your network and API base URL." }
    return "Could not complete the provider operation."
}
