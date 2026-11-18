import Foundation

func testProviderBranding() throws {
    for (url, expected) in [
        ("https://openai.com/any/path", "openai"), ("https://REGION.API.OPENAI.COM/custom", "openai"),
        ("https://anthropic.com", "anthropic"), ("https://us.api.anthropic.com/another/v3", "anthropic"),
        ("https://googleapis.com/v1", "google"), ("https://region.googleapis.com/custom", "google"),
        ("https://notopenai.com/v1", "custom"), ("https://openai.com.example.invalid", "custom"),
        ("https://evilgoogleapis.com", "custom"), ("http://localhost:11434/v1", "custom")
    ] {
        let account: ChatJSON = ["api": "responses", "preset": "custom", "baseURL": url]
        precondition(ProviderBranding.brand(account) == expected)
        precondition(ProviderBranding.preset(account) == "custom")
    }
    let first = UUID().uuidString, second = UUID().uuidString
    func legacy(_ id: String, _ client: String) -> ChatJSON {
        ["id": id, "api": "chatgpt", "baseURL": ChatGPTHTTP.resource, "clientID": client,
         "name": "ChatGPT · fixture@example.invalid · " + client.suffix(6),
         "catalog": [["id": "model", "name": "Model"]], "visibility": ["model": true], "autoAdd": true]
    }
    let values = [legacy(first, "issued123456"), legacy(second, "issuedabcdef")]
    try JSONSerialization.data(withJSONObject: ["version": 1, "accounts": values]).write(to: ProviderStore.path)
    ProviderStore.loaded = nil
    let accounts = ProviderStore.accounts()
    precondition(accounts.map { $0["name"] as! String } == Array(repeating: "ChatGPT · fixture@example.invalid", count: 2))
    for (old, clean) in zip(values, accounts) {
        for key in ["id", "clientID", "catalog", "visibility", "autoAdd", "baseURL"] {
            precondition(NSDictionary(dictionary: [key: old[key]!]).isEqual(to: [key: clean[key]!]))
        }
    }
    var intentional = values[0]; intentional["name"] = "My account · 123456"
    precondition(ProviderBranding.normalized(intentional)["name"] as? String == intentional["name"] as? String)
    var unrelated = values[0]; unrelated["name"] = "ChatGPT · fixture@example.invalid · DIFFER"
    precondition(ProviderBranding.normalized(unrelated)["name"] as? String == unrelated["name"] as? String)
    let input: ChatJSON = ["id": UUID().uuidString, "name": "Custom", "preset": "custom", "api": "responses", "baseURL": "http://127.0.0.1:1/v1"]
    precondition(ChatProviders.save(input as NSDictionary, key: nil) == nil)
    precondition(ChatProviders.account(input["id"] as! String)?["preset"] as? String == "custom")
    print("PASS domain branding, preset independence, legacy names and duplicate-account identity")
}
