import Foundation
import Darwin

// Opt-in local diagnostics contain routing metadata only, never credentials or conversation text.
@objc(DPProviderAudit) final class ProviderAudit: NSObject {
    private static let lock = NSLock()
    @objc(record:fields:) static func record(_ phase: String, fields: NSDictionary) {
        guard let path = ProcessInfo.processInfo.environment["DIATWEAKS_MODEL_AUDIT"] else { return }
        lock.lock(); defer { lock.unlock() }
        let file = open(path, O_WRONLY | O_APPEND | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard file >= 0 else { return }; defer { close(file) }
        var info = stat()
        guard fstat(file, &info) == 0, info.st_uid == geteuid(), info.st_nlink == 1, info.st_size < 256 * 1024 else { return }
        var value = fields as? ChatJSON ?? [:]
        value["phase"] = phase; value["time"] = Date().timeIntervalSince1970
        guard var data = try? JSONSerialization.data(withJSONObject: value, options: .sortedKeys) else { return }
        data.append(10)
        _ = data.withUnsafeBytes { Darwin.write(file, $0.baseAddress!, $0.count) }
    }
}

func providerAudit(_ phase: String, _ fields: ChatJSON = [:]) { ProviderAudit.record(phase, fields: fields as NSDictionary) }
