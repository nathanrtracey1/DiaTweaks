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
            providerAudit("provider-start", ["api": provider["api"] ?? "", "model": provider["model"] ?? ""])
            var problem: String?
            var recordedError = ""
            let wire = ProviderWire(model: provider["model"] as? String ?? "", emit: chunk)
            do {
                if let error = provider["error"] as? String { throw NSError(domain: "ChatModel", code: 1, userInfo: [NSLocalizedDescriptionKey: error]) }
                guard let payload = body as? ChatJSON else { throw ProviderError.invalidResponse }
                if provider["api"] as? String == "anthropic" {
                    try await streamAnthropic(payload, provider: provider, chunk: chunk, calls: calls)
                } else if provider["api"] as? String == "apple" {
                    let result = provider["_safety"] as? Bool == true ? try await runAppleSafety(payload, delta: wire.text) : try await runAppleChat(payload, delta: wire.text)
                    try Task.checkCancellation()
                    try wire.finish(result, calls: calls)
                } else {
                    let connection = provider["api"] as? String == "chatgpt" ? try await ChatGPTAccess.provider(provider) : provider
                    let result = try await runOpenAIChat(payload, provider: connection, history: reasoning, delta: wire.text)
                    try Task.checkCancellation()
                    try wire.finish(result, calls: calls)
                }
            } catch {
                recordedError = provider["error"] as? String ?? providerMessage(error)
                if !(error is CancellationError) && !Task.isCancelled {
                    var message = recordedError
                    if case ChatGPTError.usage = error { message += " [Manage usage](https://chatgpt.com/settings/usage)." }
                    do { try wire.failure(message, calls: calls) }
                    catch { problem = providerMessage(error) }
                }
            }
            self.finish()
            providerAudit("provider-finished", ["api": provider["api"] ?? "", "error": recordedError])
            completion(problem)
        }
    }
    private func finish() { lock.lock(); task = nil; lock.unlock() }
}
