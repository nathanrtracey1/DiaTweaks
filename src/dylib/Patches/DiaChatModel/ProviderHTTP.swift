import Foundation

final class ProviderNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

enum ProviderHTTP {
    static func base(_ value: String) throws -> URL {
        guard let url = URL(string: value), let host = url.host?.lowercased(),
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host)),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { throw ProviderError.invalidURL }
        return url
    }
    static func request(_ account: ChatJSON, path: String) throws -> URLRequest {
        let base = try base(account["baseURL"] as? String ?? "")
        var request = URLRequest(url: base.appendingPathComponent(path), timeoutInterval: 120)
        if let key = account["credential"] as? String, !key.isEmpty {
            if account["api"] as? String == "anthropic" { request.setValue(key, forHTTPHeaderField: "X-Api-Key") }
            else { request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization") }
        }
        if account["api"] as? String == "anthropic" { request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    static func session() -> URLSession { URLSession(configuration: .ephemeral, delegate: ProviderNoRedirect(), delegateQueue: nil) }
    static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return
        case 401, 403: throw ProviderError.authentication
        case 429: throw ProviderError.rateLimited
        default: throw ProviderError.invalidResponse
        }
    }
    static func catalog(_ account: ChatJSON) async throws -> [ChatJSON] {
        let session = session(); defer { session.invalidateAndCancel() }
        var catalog: [ChatJSON] = [], seen = Set<String>(), cursors = Set<String>()
        var cursor: String?
        repeat {
            var request = try request(account, path: "models")
            if let cursor {
                var url = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
                url.queryItems = [URLQueryItem(name: account["api"] as? String == "anthropic" ? "after_id" : "after", value: cursor)]
                request.url = url.url
            }
            let (data, response) = try await session.data(for: request)
            try check(response)
            guard data.count <= 8 * 1024 * 1024, let object = try JSONSerialization.jsonObject(with: data) as? ChatJSON,
                  let models = object["data"] as? [ChatJSON] else { throw ProviderError.invalidResponse }
            for model in models {
                guard let id = model["id"] as? String, !id.isEmpty, seen.insert(id).inserted else { continue }
                catalog.append(["id": id, "name": model["display_name"] as? String ?? id])
            }
            cursor = object["has_more"] as? Bool == true ? (object["last_id"] as? String ?? models.last?["id"] as? String) : nil
            if object["has_more"] as? Bool == true && cursor == nil { throw ProviderError.invalidResponse }
            if let cursor, !cursors.insert(cursor).inserted { throw ProviderError.invalidResponse }
        } while cursor != nil
        return catalog
    }
}
