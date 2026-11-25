import Foundation

func testProviderHTTP(_ base: String) async throws {
    var account: ChatJSON = ["baseURL": base + "/v1", "credential": "fixture-key", "api": "responses", "model": "fixture"]
    let first = try await ProviderHTTP.catalog(account)
    precondition(first.count == 2)
    account["api"] = "anthropic"
    let second = try await ProviderHTTP.catalog(account)
    precondition(second.count == 2)
    account["baseURL"] = base + "/redirect"
    do { _ = try await ProviderHTTP.catalog(account); preconditionFailure("redirect followed") } catch {}
    let (leakData, _) = try await URLSession.shared.data(from: URL(string: base + "/leaks")!)
    let leaks = try JSONSerialization.jsonObject(with: leakData) as! ChatJSON
    precondition(leaks["count"] as? Int == 0)
    do { _ = try ProviderHTTP.base("http://example.com/v1"); preconditionFailure("remote plaintext allowed") } catch {}
    let payload: ChatJSON = ["messages": [["role": "user", "content": "hi"]]]
    account["baseURL"] = base + "/v1"
    for api in ["responses", "chat-completions"] {
        account["api"] = api
        var text = ""
        let result = try await runOpenAIChat(payload, provider: account, history: ProviderReasoning()) { text += $0 }
        precondition(text == "hello" && result.text == text)
    }
    account["model"] = "broken"; account["api"] = "responses"
    do { _ = try await runOpenAIChat(payload, provider: account, history: ProviderReasoning()) { _ in }; preconditionFailure("incomplete accepted") } catch {}
    account["model"] = "slow"
    let cancelledAccount = account
    let task = Task { try await runOpenAIChat(payload, provider: cancelledAccount, history: ProviderReasoning()) { _ in } }
    try await Task.sleep(nanoseconds: 100_000_000); task.cancel()
    do { _ = try await task.value; preconditionFailure("cancel ignored") } catch {}
    account["api"] = "anthropic"; account["model"] = "fixture"
    var stream = ""
    try await streamAnthropic(payload, provider: account, chunk: { stream += $0 }, calls: { _ in })
    precondition(stream.contains("message_stop") && stream.contains("hello"))
    let request = try OpenAIChatRequest(["messages": [["role": "assistant", "content": [
        ["type": "tool_use", "id": "call-1", "name": "Read", "input": ["file_path": "a"]]]],
        ["role": "user", "content": [["type": "tool_result", "tool_use_id": "call-1", "content": "contents"]]]]], model: "fixture", responses: true)
    let items = request.body["input"] as! [ChatJSON]
    precondition(items[0]["call_id"] as? String == "call-1" && items[1]["call_id"] as? String == "call-1")
    print("PASS paginated catalogs, formats, stream completion, cancellation, redirects and tool IDs")
}
