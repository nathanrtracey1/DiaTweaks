import Foundation

func testProviderStore() throws {
    let id = UUID().uuidString
    let input: ChatJSON = ["id": id, "name": "Fixture", "api": "responses", "baseURL": "http://127.0.0.1:1/v1"]
    precondition(ChatProviders.save(input as NSDictionary, key: "fixture-key") == nil)
    precondition(ChatProviders.snapshot(id)["credential"] as? String == "fixture-key")
    let reads = ProviderSecrets.reads
    precondition(ChatProviders.account(id) != nil && ChatProviders.credentialAvailable(id))
    precondition(ProviderSecrets.reads == reads)
    let appleID = UUID().uuidString
    var accounts = ProviderStore.accounts()
    accounts.append(["id": appleID, "name": "Apple Intelligence", "api": "apple", "baseURL": "", "autoAdd": true,
        "visibility": [String: Bool](), "catalog": [ChatJSON]()])
    try ProviderStore.write(accounts)
    precondition(ChatProviders.snapshot(appleID)["credential"] == nil && ProviderSecrets.reads == reads)
    try ProviderStore.write(ProviderStore.accounts().filter { $0["id"] as? String != appleID })
    let saved = try String(contentsOf: ProviderStore.path, encoding: .utf8)
    precondition(!saved.contains("fixture-key"))
    try ProviderStore.change(id) { account in
        ProviderStore.merge([["id": "a", "name": "A"], ["id": "b", "name": "B"]], into: &account)
    }
    precondition(ChatProviders.visibility(id, model: "a", shown: false) == nil)
    try ProviderStore.change(id) { ProviderStore.merge([["id": "a", "name": "A"], ["id": "c", "name": "C"]], into: &$0) }
    var account = ChatProviders.account(id) as! ChatJSON
    var visibility = account["visibility"] as! [String: Bool]
    precondition(visibility["a"] == false && visibility["c"] == true)
    precondition(ChatProviders.showAll(id, shown: false) == nil)
    precondition(ChatProviders.futureModels(id, enabled: false) == nil)
    try ProviderStore.change(id) { ProviderStore.merge([["id": "d", "name": "D"]], into: &$0) }
    account = ChatProviders.account(id) as! ChatJSON; visibility = account["visibility"] as! [String: Bool]
    precondition(visibility["d"] == false && visibility["a"] == false)
    precondition(ChatProviders.addModel(id, model: "manual") == nil)
    precondition((ChatProviders.account(id)?["visibility"] as? [String: Bool])?["manual"] == true)
    ProviderSecrets.fail = true
    precondition(ChatProviders.save(input as NSDictionary, key: "replacement") != nil)
    precondition(ChatProviders.snapshot(id)["error"] != nil)
    precondition(ChatProviders.remove(id) != nil)
    ProviderSecrets.fail = false
    precondition(ChatProviders.remove(id) == nil && ChatProviders.account(id) == nil)
    print("PASS provider visibility, future models, manual IDs, credential isolation and Keychain failures")
}
