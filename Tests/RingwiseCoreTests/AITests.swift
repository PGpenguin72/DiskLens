import Foundation
import Testing
@testable import RingwiseCore

private func item(_ path: String, size: Int64, dir: Bool = true, children: [String] = []) -> AIItem {
    AIItem(path: path, isDirectory: dir, size: size, itemCount: dir ? 12 : 1,
           modified: Date(timeIntervalSince1970: 1_760_000_000), children: children)
}

// MARK: Prompt

@Test func promptContainsMetadataOnly() throws {
    // A real file with recognisable contents: its contents must never reach the prompt.
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ai-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("secret.txt")
    try "TOP-SECRET-CONTENTS".write(to: file, atomically: true, encoding: .utf8)

    let prompt = AIPromptBuilder.build(items: [item(file.path, size: 4096, dir: false)], language: "zh-Hant-TW")
    #expect(prompt.text.contains(file.path))
    #expect(!prompt.text.contains("TOP-SECRET-CONTENTS"))
    #expect(prompt.text.contains("never file contents"))
    #expect(prompt.text.contains("Traditional Chinese (Taiwan)"))
    #expect(prompt.text.contains("\"safety\""))
}

@Test func promptCapsAtTwentyBiggestFirst() {
    let items = (1...35).map { item("/tmp/x/item\($0)", size: Int64($0) * 1_000_000) }
    let prompt = AIPromptBuilder.build(items: items, language: "en", maxItems: 50)
    #expect(prompt.items.count == 20)
    #expect(prompt.omitted == 15)
    #expect(prompt.items.first?.path == "/tmp/x/item35")
    #expect(prompt.text.contains("/tmp/x/item16"))
    #expect(!prompt.text.contains("/tmp/x/item15 "))
}

@Test func promptRespectsProviderLimits() {
    let kids = (1...12).map { "child\($0)" }
    let items = (1...15).map { item("/tmp/y/f\($0)", size: Int64($0), children: kids) }
    let prompt = AIPromptBuilder.build(items: items, info: AppleOnDeviceProvider.info, language: "en")
    #expect(prompt.items.count == 10)
    #expect(prompt.text.contains("child3"))
    #expect(!prompt.text.contains("child4"))
    // Guided generation: no JSON format spec needed.
    #expect(!prompt.text.contains("Reply with ONLY"))
}

@Test func languageNames() {
    #expect(AIPromptBuilder.languageName("zh-Hant-TW") == "Traditional Chinese (Taiwan)")
    #expect(AIPromptBuilder.languageName("zh-Hans") == "Simplified Chinese")
    #expect(AIPromptBuilder.languageName("en") == "English")
    #expect(AIPromptBuilder.languageName("ja-JP") == "Japanese (Japan)")
}

// MARK: Parsing

private let sample = #"[{"path":"/a","what":"Cache.","owner":"Apple","safety":"safe","impact":"Rebuilt.","confidence":0.9}]"#

@Test func parsesPlainArray() throws {
    let r = try AIResponseParser.parse(sample)
    #expect(r == [AIExplanation(path: "/a", what: "Cache.", owner: "Apple", safety: .safe, impact: "Rebuilt.", confidence: 0.9)])
}

@Test func parsesFencedJSONWithProse() throws {
    let raw = "Sure! Here you go:\n```json\n" + sample + "\n```\nLet me know [if] you need more."
    #expect(try AIResponseParser.parse(raw).first?.path == "/a")
}

@Test func unwrapsClaudeEnvelope() throws {
    let envelope = try String(decoding: JSONSerialization.data(withJSONObject: [
        "type": "result", "is_error": false, "result": "```json\n" + sample + "\n```",
    ]), as: UTF8.self)
    #expect(try AIResponseParser.parse(envelope).first?.owner == "Apple")
}

@Test func unwrapsResponseEnvelope() throws {
    let envelope = try String(decoding: JSONSerialization.data(withJSONObject: ["status": "SUCCESS", "response": sample]), as: UTF8.self)
    #expect(try AIResponseParser.parse(envelope).count == 1)
}

@Test func envelopeErrorIsReported() {
    let envelope = #"{"type":"result","is_error":true,"result":"Invalid API key"}"#
    #expect(throws: AIError.failed("Invalid API key")) { try AIResponseParser.parse(envelope) }
}

@Test func lenientFields() throws {
    let raw = #"[{"path":"/b","what":"x","owner":"null","safety":"Caution!","impact":"y","confidence":"85%"},{"path":"/c","what":"z","safety":"KEEP"}]"#
    let r = try AIResponseParser.parse(raw)
    #expect(r[0].owner == nil)
    #expect(r[0].safety == .caution)
    #expect(abs(r[0].confidence - 0.85) < 0.001)
    #expect(r[1].safety == .keep)
}

@Test func garbageThrows() {
    #expect(throws: AIError.unparsable) { try AIResponseParser.parse("I cannot help with that.") }
    #expect(throws: AIError.unparsable) { try AIResponseParser.parse("[1, 2, 3]") }
    #expect(throws: AIError.unparsable) { try AIResponseParser.parse(#"{"foo": "bar"}"#) }
    #expect(throws: AIError.unparsable) { try AIResponseParser.parse("") }
}

@Test func matchesByPathNameAndOrder() {
    let items = [item("/x/Caches/one", size: 3), item("/x/Caches/two", size: 2), item("/x/three", size: 1)]
    let answers = [
        AIExplanation(path: "~/Caches/two", what: "2", owner: nil, safety: .safe, impact: "", confidence: 1),
        AIExplanation(path: "/x/Caches/one", what: "1", owner: nil, safety: .safe, impact: "", confidence: 1),
        AIExplanation(path: "3", what: "3", owner: nil, safety: .keep, impact: "", confidence: 1),
    ]
    let m = AIResponseParser.match(answers, to: items)
    #expect(m["/x/Caches/one"]?.what == "1")
    #expect(m["/x/Caches/two"]?.what == "2")
    #expect(m["/x/three"]?.what == "3")
    #expect(m["/x/three"]?.path == "/x/three")
}

// MARK: Cache

@Test func cacheKeysBySizeBucketAndProvider() throws {
    var cache = AICache()
    let a = item("/p", size: 1_000_000)
    let e = AIExplanation(path: "/p", what: "w", owner: nil, safety: .safe, impact: "", confidence: 1)
    cache.store(e, for: a, providerID: "claude")
    #expect(cache.lookup(a, providerID: "claude") != nil)
    #expect(cache.lookup(a, providerID: "codex") == nil)
    #expect(cache.lookup(item("/p", size: 3_000_000), providerID: "claude") == nil)

    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ai-cache-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    try cache.save(to: url)
    #expect(AICache.load(from: url).lookup(a, providerID: "claude")?.explanation == e)
}

// MARK: CLI arguments

#if !APP_STORE
private let prompt = AIPromptBuilder.build(items: [item("/Users/me/Library/Caches/foo bar; rm -rf ~", size: 10)], language: "en")

private func invocation(_ spec: CLIProviderSpec, model: String? = nil) -> CLIInvocation {
    CLIProvider(spec: spec, executable: URL(fileURLWithPath: "/opt/tools/\(spec.binaryNames[0])"))
        .invocation(for: prompt, options: AIRequestOptions(model: model, timeout: 60))
}

@Test func claudeArgumentsDisableTools() {
    let inv = invocation(CLIProviders.claude, model: "sonnet")
    #expect(inv.arguments.starts(with: ["-p", "--output-format", "json"]))
    let tools = inv.arguments.firstIndex(of: "--tools")!
    #expect(inv.arguments[tools + 1] == "")
    #expect(inv.arguments.contains("plan"))
    #expect(inv.arguments.contains("--safe-mode"))
    #expect(inv.arguments.suffix(2) == ["--model", "sonnet"])
    #expect(inv.stdin == prompt.text)
    #expect(!inv.arguments.contains(prompt.text))
}

@Test func codexArgumentsAreReadOnly() {
    let inv = invocation(CLIProviders.codex)
    #expect(inv.arguments.first == "exec")
    #expect(inv.arguments.contains("read-only"))
    #expect(inv.arguments.contains("--skip-git-repo-check"))
    #expect(inv.arguments.last == "-")
    #expect(!inv.arguments.contains("--model"))
    #expect(inv.stdin == prompt.text)
}

@Test func agyOpencodeGeminiArguments() {
    let agy = invocation(CLIProviders.antigravity)
    #expect(agy.arguments[0...1] == ["-p", prompt.text][...])
    #expect(agy.arguments.contains("plan") && agy.arguments.contains("--sandbox"))
    #expect(agy.arguments.contains("60s"))

    let oc = invocation(CLIProviders.opencode, model: "anthropic/claude")
    #expect(oc.arguments.starts(with: ["run", "--agent", "plan", "--model", "anthropic/claude"]))
    #expect(oc.arguments.last == prompt.text)
    #expect(oc.environment["OPENCODE_CONFIG_CONTENT"]?.contains(#""*":"deny""#) == true)

    let gemini = invocation(CLIProviders.gemini)
    #expect(gemini.arguments.suffix(2) == ["-p", prompt.text])
}

@Test func environmentIsMinimal() {
    let env = invocation(CLIProviders.claude).environment
    #expect(env["PATH"]?.hasPrefix("/opt/tools:") == true)
    #expect(env["HOME"] == NSHomeDirectory())
    #expect(Set(env.keys).isSubset(of: ["PATH", "HOME", "NO_COLOR", "TERM", "USER", "LOGNAME", "TMPDIR", "LANG", "SHELL"]))
}

@Test func providerListIsDataDriven() {
    let ids = CLIProviders.all.map(\.info.id)
    #expect(ids == ["claude", "codex", "agy", "opencode", "gemini"])
    #expect(Set(ids).count == ids.count)
    #expect(AIProviderRegistry.supported.first?.id == "apple")
}

@Test func cliErrorMapping() {
    let spec = CLIProviders.claude
    let notLoggedIn = CLIResult(status: 1, stdout: "", stderr: "Error: Not logged in · Please run /login", timedOut: false)
    #expect(CLIRunner.error(for: notLoggedIn, spec: spec) == .notLoggedIn(tool: "Claude Code", command: "claude"))
    let crash = CLIResult(status: 2, stdout: "", stderr: "\u{1B}[91mboom\u{1B}[0m", timedOut: false)
    #expect(CLIRunner.error(for: crash, spec: spec) == .failed("boom"))
    let ok = CLIResult(status: 0, stdout: sample, stderr: "warning: whatever", timedOut: false)
    #expect(CLIRunner.error(for: ok, spec: spec) == nil)
}

@Test func runnerCapturesOutputAndTimesOut() async throws {
    let echo = try await CLIRunner.run(executable: URL(fileURLWithPath: "/bin/cat"),
                                       invocation: CLIInvocation(arguments: [], stdin: "hello"),
                                       workingDirectory: nil, timeout: 5)
    #expect(echo.stdout == "hello" && echo.status == 0)
    let slow = try await CLIRunner.run(executable: URL(fileURLWithPath: "/bin/sleep"),
                                       invocation: CLIInvocation(arguments: ["10"]), workingDirectory: nil, timeout: 0.3)
    #expect(slow.timedOut)
}
#endif
