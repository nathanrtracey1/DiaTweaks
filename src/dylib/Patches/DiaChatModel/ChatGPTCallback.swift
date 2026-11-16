import Foundation
import Network

final class ChatGPTCallback: @unchecked Sendable {
    let listener: NWListener
    let state: String
    private let queue = DispatchQueue(label: "com.diapatches.chatgpt-callback")
    private var ready: CheckedContinuation<UInt16, Error>?
    private var callback: CheckedContinuation<[String: String], Error>?
    private var result: Result<[String: String], Error>?
    init(state: String) throws {
        self.state = state
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }
    func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.ready = continuation
                self.listener.stateUpdateHandler = { [weak self = self] state in
                    guard let self else { return }
                    if case .ready = state, let port = self.listener.port {
                        self.ready?.resume(returning: port.rawValue); self.ready = nil
                    } else if case .failed(let error) = state { self.finish(.failure(error)) }
                }
                self.listener.newConnectionHandler = { [weak self = self] connection in
                    connection.start(queue: self?.queue ?? .global())
                    self?.receive(connection, data: Data())
                }
                self.listener.start(queue: self.queue)
                self.queue.asyncAfter(deadline: .now() + 300) { self.finish(.failure(ChatGPTError.cancelled)) }
            }
        }
    }
    func wait() async throws -> [String: String] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if let result = self.result { continuation.resume(with: result) }
                else { self.callback = continuation }
            }
        }
    }
    func cancel() { queue.async { self.finish(.failure(ChatGPTError.cancelled)) } }
    static func parameters(_ target: String, state: String) throws -> [String: String] {
        guard let url = URLComponents(string: "http://127.0.0.1" + target), url.path == "/auth/callback" else { throw ChatGPTError.callback }
        var values: [String: String] = [:]
        for item in url.queryItems ?? [] {
            guard values[item.name] == nil, let value = item.value else { throw ChatGPTError.callback }
            values[item.name] = value
        }
        guard values["state"] == state else { throw ChatGPTError.callback }
        if values["error"] != nil { throw ChatGPTError.cancelled }
        guard values["code"]?.isEmpty == false else { throw ChatGPTError.callback }
        return values
    }
    private func receive(_ connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] part, _, ended, error in
            guard let self else { connection.cancel(); return }
            let data = data + (part ?? Data())
            guard data.count <= 16384, error == nil else { connection.cancel(); return }
            guard let text = String(data: data, encoding: .utf8), text.contains("\r\n\r\n") else {
                if !ended { self.receive(connection, data: data) } else { connection.cancel() }; return
            }
            let line = text.components(separatedBy: "\r\n")[0].components(separatedBy: " ")
            let parsed = Result { () -> [String: String] in
                guard line.count == 3, line[0] == "GET" else { throw ChatGPTError.callback }
                return try Self.parameters(line[1], state: self.state)
            }
            let succeeded = (try? parsed.get()) != nil
            let body = succeeded ? "Sign-in complete. You can return to Dia." : "Sign-in was not completed. Return to Dia to try again."
            let response = "HTTP/1.1 \(succeeded ? "200 OK" : "400 Bad Request")\r\nContent-Type: text/plain\r\nConnection: close\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
            self.finish(parsed)
        }
    }
    private func finish(_ value: Result<[String: String], Error>) {
        guard result == nil else { return }; result = value
        ready?.resume(throwing: ChatGPTError.cancelled); ready = nil
        callback?.resume(with: value); callback = nil
        listener.cancel()
    }
}
