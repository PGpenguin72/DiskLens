import Foundation
import RingwiseCore

/// Headless check of the AI pipeline.
///
/// `RINGWISE_AI_SELFTEST=<folder>` detects providers, scans the folder and prints the prompt for
/// its largest children (`RINGWISE_AI_SELFTEST_ITEMS`, default 5). Only when
/// `RINGWISE_AI_SELFTEST_RUN=<providerId>` is also set does it launch that provider and print the
/// parsed answers — that call may use the user's AI subscription.
@MainActor
enum AISelfTest {
    static func run(path: String) -> Never {
        let env = ProcessInfo.processInfo.environment
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
        var exitCode: Int32 = 0
        let task = Task {
            defer { finished = true }
            print("Detecting AI providers…")
            let providers = await AIProviderRegistry.detect()
            for p in providers {
                let state = p.unavailableReason.map { "unavailable: \($0)" } ?? "ready"
                print("  \(p.id.padding(toLength: 9, withPad: " ", startingAt: 0)) \(p.info.displayName) — \(p.location ?? "built-in") \(p.version ?? "") [\(state)]")
            }

            print("\nScanning \(url.path)…")
            guard let tree = try? await Scanner().scan(root: url, progress: { _ in }) else {
                print("Scan failed"); exitCode = 1; return
            }
            let wanted = env["RINGWISE_AI_SELFTEST_RUN"]
            guard let provider = wanted.flatMap({ id in providers.first { $0.id == id } })
                    ?? AIProviderRegistry.defaultProvider(in: providers) ?? providers.first else {
                print("No provider"); exitCode = 1; return
            }
            let limit = Int(env["RINGWISE_AI_SELFTEST_ITEMS"] ?? "") ?? 5
            var ids = Array(tree.children(tree.root).prefix(limit))
            if ids.isEmpty { ids = [tree.root] }
            let items = ids.map { tree.aiItem($0) }
            let prompt = AIPromptBuilder.build(items: items, info: provider.info, language: AILanguage.current)
            print("\nPrompt for \(provider.info.displayName) (\(prompt.items.count) items, \(prompt.omitted) omitted, \(prompt.text.count) chars):")
            print("----\n\(prompt.text)\n----")

            guard let wanted else { return }
            guard provider.id == wanted, provider.isUsable else {
                print("Provider \(wanted) is not available"); exitCode = 1; return
            }
            print("\nAsking \(provider.info.displayName)…")
            let started = Date()
            do {
                let options = AIRequestOptions(model: env["RINGWISE_AI_SELFTEST_MODEL"],
                                               timeout: Double(env["RINGWISE_AI_SELFTEST_TIMEOUT"] ?? "") ?? 90)
                let answers = try await provider.provider.explain(prompt, options: options)
                let matched = AIResponseParser.match(answers, to: prompt.items)
                print(String(format: "Answered in %.1f s, %d/%d items matched:", Date().timeIntervalSince(started),
                             matched.count, prompt.items.count))
                for item in prompt.items {
                    guard let a = matched[item.path] else { print("  [missing] \(item.path)"); continue }
                    print("  [\(a.safety.rawValue)] \(item.name) — \(a.what)")
                    print("      owner: \(a.owner ?? "-"); impact: \(a.impact); confidence: \(a.confidence)")
                }
            } catch {
                print("Failed after \(Int(Date().timeIntervalSince(started))) s: \(error.localizedDescription)")
                exitCode = 1
            }
        }
        _ = task
        spin { !finished }
        exit(exitCode)
    }

    private static var finished = false

    private static func spin(_ condition: () -> Bool) {
        while condition() { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05)) }
    }
}
