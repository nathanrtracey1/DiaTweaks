import Foundation

@objc(DPProviderSession) final class ProviderSession: NSObject {
    let provider: ChatJSON
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var cancelled = false
    private let reasoning = ProviderReasoning()
    @objc(initWithProvider:) init(provider: NSDictionary) { self.provider = provider as? ChatJSON ?? [:]; super.init() }
    @objc func cancel() {
        lock.lock(); cancelled = true; let task = task; lock.unlock()
        task?.cancel()
    }
    @objc(start:chunk:calls:completion:) func start(_ body: NSDictionary, chunk: @escaping (String) -> Void,
                                                   calls: @escaping (NSArray) -> Void, completion: @escaping (String?) -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled, task == nil else { completion("This chat run was cancelled or is already generating."); return }
        task = Task {
            var problem: String?
            do {
                if let error = provider["error"] as? String { throw NSError(domain: "ChatModel", code: 1, userInfo: [NSLocalizedDescriptionKey: error]) }
                guard let payload = body as? ChatJSON else { throw ProviderError.invalidResponse }
                let wire = ProviderWire(model: provider["model"] as? String ?? "", emit: chunk)
                if provider["api"] as? String == "anthropic" {
                    try await streamAnthropic(payload, provider: provider, chunk: chunk, calls: calls)
                } else {
                    let result = try await runOpenAIChat(payload, provider: provider, history: reasoning, delta: wire.text)
                    try Task.checkCancellation()
                    try wire.finish(result, calls: calls)
                }
            } catch { problem = provider["error"] as? String ?? providerMessage(error) }
            self.finish()
            completion(problem)
        }
    }
    private func finish() { lock.lock(); task = nil; lock.unlock() }
}
