import Foundation

extension ChatProviders {
    @objc(addModel:model:) static func addModel(_ id: String, model: String) -> String? {
        guard !model.isEmpty, model.utf8.count <= 256 else { return "Enter a model ID." }
        do {
            try ProviderStore.change(id) { account in
                var models = account["manualModels"] as? [ChatJSON] ?? []
                if !models.contains(where: { $0["id"] as? String == model }) { models.append(["id": model, "name": model]) }
                account["manualModels"] = models
                var catalog = account["catalog"] as? [ChatJSON] ?? []
                if !catalog.contains(where: { $0["id"] as? String == model }) { catalog.append(["id": model, "name": model]) }
                ProviderStore.merge(catalog, into: &account)
                var visibility = account["visibility"] as? [String: Bool] ?? [:]
                visibility[model] = true; account["visibility"] = visibility
            }
            ProviderStore.changed(); return nil
        } catch { return providerMessage(error) }
    }
    private static var refreshing: [String: [(String?) -> Void]] = [:]
    private static var errors: [String: String] = [:]
    @objc static func status(_ id: String) -> String? { errors[id] }
    @objc(refresh:force:completion:) static func refresh(_ id: String, force: Bool, completion: @escaping (String?) -> Void) {
        if !Thread.isMainThread { DispatchQueue.main.async { refresh(id, force: force, completion: completion) }; return }
        guard let account = account(id) as? ChatJSON else { completion(ProviderError.removed.localizedDescription); return }
        if !force, Date().timeIntervalSince1970 - (account["refreshed"] as? Double ?? 0) < 3600 { completion(nil); return }
        if refreshing[id] != nil { refreshing[id]?.append(completion); return }
        refreshing[id] = [completion]
        let snapshot = snapshot(id) as! ChatJSON
        Task {
            var problem: String?
            do {
                if let message = snapshot["error"] as? String { throw NSError(domain: "ChatModel", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
                let catalog = try await ProviderHTTP.catalog(snapshot)
                try ProviderStore.change(id) { current in
                    guard current["revision"] as? Int == account["revision"] as? Int else { return }
                    let ids = Set(catalog.compactMap { $0["id"] as? String })
                    let manual = (current["manualModels"] as? [ChatJSON] ?? []).filter { !ids.contains($0["id"] as? String ?? "") }
                    ProviderStore.merge(catalog + manual, into: &current)
                }
                ProviderStore.changed()
            } catch { problem = (snapshot["error"] as? String) ?? providerMessage(error) }
            let result = problem
            await MainActor.run {
                errors[id] = result
                ProviderStore.changed()
                let callbacks = refreshing.removeValue(forKey: id) ?? []
                callbacks.forEach { $0(result) }
            }
        }
    }
    @objc(visibility:model:shown:) static func visibility(_ id: String, model: String, shown: Bool) -> String? {
        do {
            try ProviderStore.change(id) { account in
                var values = account["visibility"] as? [String: Bool] ?? [:]
                values[model] = shown; account["visibility"] = values
            }
            ProviderStore.changed(); return nil
        } catch { return providerMessage(error) }
    }
    @objc(showAll:shown:) static func showAll(_ id: String, shown: Bool) -> String? {
        do {
            try ProviderStore.change(id) { account in
                var values = account["visibility"] as? [String: Bool] ?? [:]
                for item in account["catalog"] as? [ChatJSON] ?? [] {
                    if let model = item["id"] as? String { values[model] = shown }
                }
                account["visibility"] = values
            }
            ProviderStore.changed(); return nil
        } catch { return providerMessage(error) }
    }
    @objc(futureModels:enabled:) static func futureModels(_ id: String, enabled: Bool) -> String? {
        do { try ProviderStore.change(id) { $0["autoAdd"] = enabled }; ProviderStore.changed(); return nil }
        catch { return providerMessage(error) }
    }
}
