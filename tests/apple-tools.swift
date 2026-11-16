import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

func testAppleTools() async throws {
    #if canImport(FoundationModels)
    if #available(macOS 26, *), AppleProvider.available {
        let file: ChatJSON = ["name": "Read", "description": "Read the contents of a local file using its file_path.",
            "input_schema": ["type": "object", "properties": ["file_path": ["type": "string"]], "required": ["file_path"]]]
        var tabs: ChatJSON = ["name": "mcp__dia-tools__read_tabs", "description": "Get metadata and page content for the tabs currently open in the browser window.",
            "input_schema": ["type": "object", "properties": [
                "contentPaneIDs": ["description": "Content pane IDs to read, or an empty array to read all open content panes.", "type": "array", "items": ["type": "string"]],
                "includeFullTextContent": ["description": "Include page text only when needed. Metadata is always included.", "type": "boolean"]],
                "required": ["contentPaneIDs", "includeFullTextContent"]]]
        // Use the installed app's unmodified definition when running the native audit.
        if let app = ProcessInfo.processInfo.environment["DIATWEAKS_TEST_DIA"] {
            let path = app + "/Contents/Resources/agent-server-resources/dist/resources/tool-schemas/dia.json"
            let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! ChatJSON
            let definition = (catalog["tools"] as! [ChatJSON]).first { $0["name"] as? String == "read_tabs" }!
            tabs = ["name": "mcp__dia-tools__read_tabs", "description": definition["description"]!, "input_schema": definition["inputSchema"]!]
        }
        let prompts = ["Which browser pages are currently open? Give their titles.", "Enumera las pestañas que tengo abiertas."]
        for prompt in prompts {
            print("CHECK Apple tool round trip: \(prompt)")
            let request: ChatJSON = ["messages": [["role": "user", "content": prompt]], "tools": [file, tabs]]
            let result = try await runAppleChat(request) { _ in }
            precondition(result.text.isEmpty && result.calls.count == 1, "Expected a model-selected tool call for \(prompt)")
            let call = result.calls[0]
            precondition(call.name == tabs["name"] as? String)
            let input = try JSONSerialization.jsonObject(with: Data(call.arguments.utf8)) as! ChatJSON
            precondition((input["contentPaneIDs"] as? [String])?.isEmpty == true && input["includeFullTextContent"] is Bool, "Invalid all-tabs arguments: \(call.arguments)")
            let tools = [file, tabs]
            let context = try await AppleContext(request)
            var renamed = tabs
            renamed["name"] = "fixture_opaque_72"
            let selected = try await appleTool(context: context, tools: [file, renamed])
            precondition(selected?["name"] as? String == "fixture_opaque_72", "Tool selection must follow the supplied description")
            func continuation(_ text: String, failed: Bool) -> ChatJSON {
                ["messages": [["role": "user", "content": prompt],
                    ["role": "assistant", "content": [["type": "tool_use", "id": call.id, "name": call.name, "input": input]]],
                    ["role": "user", "content": [["type": "tool_result", "tool_use_id": call.id, "is_error": failed, "content": text]]]],
                    "tools": tools]
            }
            let xml = "{\"result\":\"<function-response><read-tabs><unpinned-tabs><tab><title>Pine Observatory 732</title></tab><tab><title>Cedar Archive 481</title></tab></unpinned-tabs></read-tabs></function-response>\"}"
            var streamed = ""
            let answer = try await runAppleChat(continuation(xml, failed: false)) { streamed += $0 }
            precondition(answer.calls.isEmpty && answer.text == streamed && answer.text.contains("Pine Observatory 732") && answer.text.contains("Cedar Archive 481"))
            for failure in ["Permission denied by the user. Browser tab contents were not returned.", "The browser tool failed: the tab service is unavailable. No tab metadata was returned."] {
                print("CHECK Apple failed result: \(failure)")
                let failed = try await runAppleChat(continuation(failure, failed: true)) { _ in }
                precondition(failed.calls.isEmpty && !failed.text.isEmpty && !failed.text.contains("Pine Observatory 732") && !failed.text.contains("Cedar Archive 481"))
            }
        }
        let page = "<attachment title=\"Observatory\">The Pine Observatory opens Saturday. Tickets cost $12.</attachment>"
        let summary = try await runAppleChat(["messages": [["role": "user", "content": page + "<user-message>Summarize this page.</user-message>"]], "tools": [file, tabs]]) { _ in }
        precondition(summary.calls.isEmpty && summary.text.contains("Observatory"))
        print("PASS model-driven Apple tool selection, supplied names, multilingual requests, continuations, denied/failed results and attached pages")
    }
    #endif
}
