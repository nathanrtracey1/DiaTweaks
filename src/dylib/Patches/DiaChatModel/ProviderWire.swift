import Foundation

final class ProviderWire {
    private let model: String
    private let emit: (String) -> Void
    private var started = false
    private var textStarted = false
    init(model: String, emit: @escaping (String) -> Void) { self.model = model; self.emit = emit }
    func event(_ type: String, _ data: ChatJSON) {
        guard let data = try? JSONSerialization.data(withJSONObject: data), let json = String(data: data, encoding: .utf8) else { return }
        emit("event: \(type)\ndata: \(json)\n\n")
    }
    func start() {
        guard !started else { return }; started = true
        event("message_start", ["type": "message_start", "message": ["id": "msg_" + UUID().uuidString,
              "type": "message", "role": "assistant", "model": model, "content": [], "stop_reason": NSNull(),
              "stop_sequence": NSNull(), "usage": ["input_tokens": 0, "output_tokens": 0]]])
    }
    func text(_ delta: String) {
        guard !delta.isEmpty else { return }; start()
        if !textStarted {
            event("content_block_start", ["type": "content_block_start", "index": 0, "content_block": ["type": "text", "text": ""]])
            textStarted = true
        }
        event("content_block_delta", ["type": "content_block_delta", "index": 0, "delta": ["type": "text_delta", "text": delta]])
    }
    func finish(_ result: ChatProviderResult, calls: (NSArray) -> Void) throws {
        let tools: [ChatJSON] = try result.calls.map { call in
            guard let input = try JSONSerialization.jsonObject(with: Data(call.arguments.utf8)) as? ChatJSON else { throw ProviderError.invalidResponse }
            return ["id": call.id, "name": call.name, "input": input]
        }
        calls(tools as NSArray)
        start()
        if textStarted { event("content_block_stop", ["type": "content_block_stop", "index": 0]) }
        var index = textStarted ? 1 : 0
        for tool in tools {
            event("content_block_start", ["type": "content_block_start", "index": index,
                  "content_block": ["type": "tool_use", "id": tool["id"]!, "name": tool["name"]!, "input": [:]]])
            let arguments = String(decoding: try JSONSerialization.data(withJSONObject: tool["input"]!), as: UTF8.self)
            event("content_block_delta", ["type": "content_block_delta", "index": index,
                  "delta": ["type": "input_json_delta", "partial_json": arguments]])
            event("content_block_stop", ["type": "content_block_stop", "index": index]); index += 1
        }
        event("message_delta", ["type": "message_delta", "delta": ["stop_reason": tools.isEmpty ? "end_turn" : "tool_use", "stop_sequence": NSNull()],
              "usage": ["output_tokens": result.outputTokens]])
        event("message_stop", ["type": "message_stop"])
    }
}
