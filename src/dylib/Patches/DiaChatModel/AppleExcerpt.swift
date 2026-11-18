import Foundation
#if canImport(FoundationModels)
import FoundationModels

final class AppleBudget {
    private var steps = 0
    func step() throws {
        try Task.checkCancellation(); steps += 1
        guard steps <= 16 else { throw ProviderError.appleContext }
    }
}

@available(macOS 26, *)
enum AppleExcerpt {
    static var capacity: Int {
        if #available(macOS 26.4, *) { return SystemLanguageModel.default.contextSize }
        return 4096
    }
    static func count(_ text: String) async throws -> Int {
        try Task.checkCancellation()
        if #available(macOS 26.4, *) { return try await SystemLanguageModel.default.tokenCount(for: Prompt(text)) }
        return text.utf8.count // Conservative fallback without a tokenizer.
    }
    static func fit(_ text: String, tokens: Int, label: String) async throws -> String {
        if try await count(text) <= tokens { return text }
        let marker = "\n[\(label) excerpt: content omitted to fit the local model's context.]\n"
        var length = min(text.count, tokens * 2)
        while length > 0 {
            let excerpt = String(text.prefix(length * 3 / 4)) + marker + String(text.suffix(length / 4))
            if try await count(excerpt) <= tokens { return excerpt }
            length /= 2
        }
        throw ProviderError.appleContext
    }
    static func pages(_ text: String, tokens: Int) async throws -> String {
        let regex = try NSRegularExpression(pattern: "(?s)(<attachment(?:\\s[^>]*)?>)(.*?)(</attachment>)")
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var result = text
        for match in matches.reversed() {
            guard let body = Range(match.range(at: 2), in: text),
                  let start = Range(match.range(at: 1), in: text) else { continue }
            let excerpt = try await fit(String(text[body]), tokens: max(128, tokens / max(1, matches.count)), label: "Attachment")
            // Reverse replacements keep original ranges valid.
            guard let replacement = Range(match.range, in: result) else { throw ProviderError.invalidResponse }
            result.replaceSubrange(replacement, with: String(text[start]) + excerpt + "</attachment>")
        }
        return result
    }
}
#endif
