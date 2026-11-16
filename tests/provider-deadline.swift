import Foundation

private actor DeadlineGate {
    var released = false
    private var continuation: CheckedContinuation<Int, Never>?
    func wait() async -> Int {
        if released { return 7 }
        return await withCheckedContinuation { continuation = $0 }
    }
    func release() { released = true; continuation?.resume(returning: 7); continuation = nil }
}
func testProviderDeadline() async throws {
    let value = try await withProviderDeadline(seconds: 1) { 42 }
    precondition(value == 42)
    let gate = DeadlineGate()
    let watchdog = Task { try await Task.sleep(nanoseconds: 1_000_000_000); await gate.release() }
    do { _ = try await withProviderDeadline(seconds: 0.02) { await gate.wait() }; preconditionFailure("deadline ignored") }
    catch ProviderError.appleTimeout {}
    let released = await gate.released; precondition(!released, "deadline waited for an uncooperative operation")
    await gate.release(); watchdog.cancel()
    let cancelledGate = DeadlineGate()
    let work = Task { try await withProviderDeadline(seconds: 5) { await cancelledGate.wait() } }
    work.cancel()
    do { _ = try await work.value; preconditionFailure("cancellation ignored") } catch is CancellationError {}
    await cancelledGate.release()
    print("PASS deadline, uncooperative generation, cancellation and late completion")
}
