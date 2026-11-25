import Foundation

private final class ProviderDeadline<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var settled = false
    private var continuation: CheckedContinuation<Value, Error>?
    private var worker: Task<Void, Never>?, timer: Task<Void, Never>?
    func start(_ continuation: CheckedContinuation<Value, Error>, seconds: Double, operation: @escaping () async throws -> Value) {
        lock.lock()
        if settled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
        self.continuation = continuation
        worker = Task {
            do { self.finish(.success(try await operation())) }
            catch { self.finish(.failure(error)) }
        }
        timer = Task {
            do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            catch { return }
            self.finish(.failure(ProviderError.appleTimeout))
        }
        lock.unlock()
    }
    func finish(_ result: Result<Value, Error>) {
        lock.lock()
        guard !settled else { lock.unlock(); return }
        settled = true
        let continuation = continuation, worker = worker, timer = timer
        self.continuation = nil; self.worker = nil; self.timer = nil
        lock.unlock()
        worker?.cancel(); timer?.cancel(); continuation?.resume(with: result)
    }
}

func withProviderDeadline<Value>(seconds: Double, operation: @escaping () async throws -> Value) async throws -> Value {
    let deadline = ProviderDeadline<Value>()
    return try await withTaskCancellationHandler(operation: {
        try await withCheckedThrowingContinuation { deadline.start($0, seconds: seconds, operation: operation) }
    }, onCancel: { deadline.finish(.failure(CancellationError())) })
}
