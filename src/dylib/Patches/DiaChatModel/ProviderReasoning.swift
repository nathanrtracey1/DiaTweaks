import Foundation

final class ProviderReasoning {
    private var items: [String: [ChatJSON]] = [:]
    func capture(_ response: ChatJSON) {
        var reasoning: [ChatJSON] = []
        for item in response["output"] as? [ChatJSON] ?? [] {
            if item["type"] as? String == "reasoning" { reasoning.append(item) }
            if let id = item["call_id"] as? String, item["type"] as? String == "function_call" {
                items[id] = reasoning + [item]
                reasoning.removeAll()
            }
        }
    }
    func restore(into body: inout ChatJSON) {
        body["include"] = ["reasoning.encrypted_content"]
        body["input"] = (body["input"] as? [ChatJSON] ?? []).flatMap { item -> [ChatJSON] in
            guard item["type"] as? String == "function_call", let id = item["call_id"] as? String,
                  let saved = items[id] else { return [item] }
            return saved
        }
    }
}
