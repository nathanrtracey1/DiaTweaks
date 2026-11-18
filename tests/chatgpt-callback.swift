import Foundation

func testChatGPTCallback() async throws {
    let valid = try ChatGPTCallback.parameters("/auth/callback?state=expected&code=code&client_id=issued", state: "expected")
    precondition(valid["client_id"] == "issued")
    for target in ["/auth/callback?state=bad&code=x", "/auth/callback?state=expected&state=expected&code=x",
                   "/other?state=expected&code=x", "/auth/callback?state=expected&error=access_denied"] {
        do { _ = try ChatGPTCallback.parameters(target, state: "expected"); preconditionFailure("bad callback accepted") } catch {}
    }
    let listener = try ChatGPTCallback(state: "expected")
    let port = try await listener.start()
    let (data, response) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/auth/callback?state=expected&code=fixture")!)
    precondition((response as? HTTPURLResponse)?.statusCode == 200 && String(decoding: data, as: UTF8.self) == "Sign-in complete. You can return to Dia.")
    let values = try await listener.wait(); precondition(values["code"] == "fixture")
    let rejected = try ChatGPTCallback(state: "expected")
    let rejectedPort = try await rejected.start()
    let (failure, rejectedResponse) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(rejectedPort)/auth/callback?state=wrong&code=fixture")!)
    precondition((rejectedResponse as? HTTPURLResponse)?.statusCode == 400)
    precondition(String(decoding: failure, as: UTF8.self) == "Sign-in was not completed. Return to Dia to try again.")
    do { _ = try await rejected.wait(); preconditionFailure("invalid state accepted") } catch {}
    let cancelled = try ChatGPTCallback(state: "cancel")
    _ = try await cancelled.start(); cancelled.cancel()
    do { _ = try await cancelled.wait(); preconditionFailure("cancellation ignored") } catch {}
    print("PASS loopback callback, malformed states, denied consent and sign-in cancellation")
}
