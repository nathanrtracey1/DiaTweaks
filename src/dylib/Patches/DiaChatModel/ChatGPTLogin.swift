import Foundation
import AppKit

@objc(DPChatGPT) final class ChatGPTLogin: NSObject {
    private static var pending: ChatGPTCallback?
    @objc(start:completion:) static func start(_ id: String?, completion: @escaping (String?) -> Void) {
        guard pending == nil else { completion("A ChatGPT sign-in is already in progress."); return }
        do {
            let state = try oauthRandom(), nonce = try oauthRandom(), verifier = try oauthRandom()
            let listener = try ChatGPTCallback(state: state)
            pending = listener
            Task {
                var problem: String?
                do {
                    let accountID = id ?? UUID().uuidString
                    let previous = account(id)
                    let client = previous?["clientID"] as? String
                    let hint = try? ChatGPTRegistration.credentials(accountID)["id_token"] as? String
                    let port = try await listener.start()
                    let redirect = "http://127.0.0.1:\(port)/auth/callback"
                    let url = try ChatGPTRegistration.authorization(client: client, host: ChatGPTRegistration.host(), state: state,
                        nonce: nonce, verifier: verifier, redirect: redirect, hint: hint)
                    let opened = await MainActor.run { NSWorkspace.shared.open(url) }
                    guard opened else { throw ChatGPTError.cancelled }
                    let callback = try await listener.wait()
                    let issued = callback["client_id"] ?? client
                    guard let issued, !issued.isEmpty, issued != "dynamic_agent_client", client == nil || issued == client else { throw ChatGPTError.callback }
                    var profile = try ChatGPTRegistration.retainClient(id: accountID, client: issued)
                    let tokens = try await ChatGPTHTTP.tokens(["grant_type": "authorization_code", "client_id": issued,
                        "code": callback["code"]!, "code_verifier": verifier, "redirect_uri": redirect, "resource": ChatGPTHTTP.resource])
                    guard let token = tokens["id_token"] as? String else { throw ChatGPTError.identity }
                    let identity = try await ChatGPTIdentity.verify(token, client: issued, nonce: nonce)
                    guard previous?["subject"] == nil || previous?["subject"] as? String == identity["sub"] as? String else { throw ChatGPTError.identity }
                    let record = try ChatGPTAccess.record(tokens, previous: [:], client: issued)
                    profile["subject"] = identity["sub"]; profile["issuer"] = identity["iss"]
                    profile["name"] = (identity["email"] as? String).map { "ChatGPT · " + $0 } ?? "ChatGPT"
                    profile["refreshed"] = 0
                    try ChatGPTRegistration.save(profile: profile, credentials: record)
                    await ChatGPTAccess.shared.connected(accountID)
                    await MainActor.run {
                        ChatProviders.refresh(accountID, force: true) { _ in }
                    }
                } catch { problem = providerMessage(error) }
                listener.cancel()
                let result = problem
                await MainActor.run { pending = nil; completion(result) }
            }
        } catch { completion(providerMessage(error)) }
    }
    private static func account(_ id: String?) -> ChatJSON? { id.flatMap { ChatProviders.account($0) as? ChatJSON } }
    @objc static func cancel() { pending?.cancel() }
    @objc(signOut:completion:) static func signOut(_ id: String, completion: @escaping (String?) -> Void) {
        NotificationCenter.default.post(name: .init("DPSignOutChatAccount"), object: id)
        Task {
            var problem: String?
            do { try await ChatGPTAccess.shared.signOut(id) } catch { problem = providerMessage(error) }
            let result = problem
            await MainActor.run { ProviderStore.changed(); completion(result) }
        }
    }
    @objc static func showWelcome() {
        let domain = ProcessInfo.processInfo.environment["DIATWEAKS_DOMAIN"] ?? "com.diapatches"
        let defaults = UserDefaults(suiteName: domain)!
        guard !defaults.bool(forKey: "chatGPTPlanWelcome") else { return }
        defaults.set(true, forKey: "chatGPTPlanWelcome")
        let alert = NSAlert(); alert.messageText = "You’re using your ChatGPT plan"
        alert.informativeText = "Eligible requests in Dia use your ChatGPT plan. Manage usage in ChatGPT settings."
        alert.addButton(withTitle: "Got it")
        if let window = NSApp.keyWindow, window.attachedSheet == nil { alert.beginSheetModal(for: window) }
        else { alert.runModal() }
    }
}
