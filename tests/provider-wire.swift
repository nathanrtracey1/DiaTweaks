import Foundation

func testProviderWireFailure() throws {
    for partial in [false, true] {
        var chunks: [String] = []
        let wire = ProviderWire(model: "fixture", emit: { chunks.append($0) })
        if partial { wire.text("Partial reply") }
        try wire.failure("Context limit reached.", calls: { precondition($0.count == 0) })
        let events: [ChatJSON] = try chunks.flatMap { $0.components(separatedBy: "\n") }.filter { $0.hasPrefix("data: ") }.map {
            try JSONSerialization.jsonObject(with: Data($0.dropFirst(6).utf8)) as! ChatJSON
        }
        precondition(events.filter { $0["type"] as? String == "message_start" }.count == 1)
        precondition(events.filter { $0["type"] as? String == "message_stop" }.count == 1)
        let text = events.compactMap { ($0["delta"] as? ChatJSON)?["text"] as? String }.joined()
        precondition(text.contains("**Model error:** Context limit reached."))
        precondition(events.contains { ($0["delta"] as? ChatJSON)?["stop_reason"] as? String == "end_turn" })
    }
    print("PASS visible provider errors, partial streams and terminal completion")
}
