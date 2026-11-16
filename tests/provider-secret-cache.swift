import Foundation

private final class SecretReadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}

func testProviderSecretCache() throws {
    enum Failure: Error { case denied }
    let id = UUID().uuidString
    var reads = 0, writes = 0
    let first = try ProviderSecretsCache.read(id) { reads += 1; return "fixture-key" }
    precondition(first == "fixture-key" && ProviderSecretsCache.available(id))
    for _ in 0..<20 {
        let cached = try ProviderSecretsCache.read(id) { reads += 1; return "unexpected" }
        precondition(cached == first)
    }
    precondition(reads == 1)
    try ProviderSecretsCache.write(id, value: "rotated-token") { writes += 1 }
    let rotated = try ProviderSecretsCache.read(id) { reads += 1; return "unexpected" }
    precondition(rotated == "rotated-token" && writes == 1 && reads == 1)
    do {
        try ProviderSecretsCache.write(id, value: "rejected") { throw Failure.denied }
        preconditionFailure("write failure was ignored")
    } catch Failure.denied {}
    let unchanged = try ProviderSecretsCache.read(id) { preconditionFailure("reread after failed write") }
    precondition(unchanged == "rotated-token")
    try ProviderSecretsCache.write(id, value: nil) { writes += 1 }
    let signedOut = try ProviderSecretsCache.read(id) { preconditionFailure("reread after sign-out") }
    precondition(signedOut == nil && !ProviderSecretsCache.available(id))

    let other = UUID().uuidString
    let separate = try ProviderSecretsCache.read(other) { "other-account" }
    precondition(separate == "other-account")
    precondition(!ProviderSecretsCache.available(id) && ProviderSecretsCache.available(other))
    let missing = UUID().uuidString
    let absent = try ProviderSecretsCache.read(missing) { reads += 1; return nil }
    let stillAbsent = try ProviderSecretsCache.read(missing) { preconditionFailure("reread missing credential") }
    precondition(absent == nil && stillAbsent == nil && reads == 2)
    let denied = UUID().uuidString
    do {
        _ = try ProviderSecretsCache.read(denied) { throw Failure.denied }
        preconditionFailure("read failure was ignored")
    } catch Failure.denied {}
    precondition(!ProviderSecretsCache.available(denied))
    let recovered = try ProviderSecretsCache.read(denied) { "after-user-authorization" }
    precondition(recovered == "after-user-authorization")

    let concurrent = UUID().uuidString, counter = SecretReadCounter()
    DispatchQueue.concurrentPerform(iterations: 16) { _ in
        let key = try! ProviderSecretsCache.read(concurrent) {
            counter.increment(); Thread.sleep(forTimeInterval: 0.01); return "one-keychain-read"
        }
        precondition(key == "one-keychain-read")
    }
    precondition(counter.value == 1)
    print("PASS memory-only credential reuse, concurrent reads, account isolation, rotation, sign-out and failed authorization")
}
