#if !APP_STORE
import Foundation

/// How to launch a CLI for one request: arguments (never a shell string), stdin and extra environment.
public struct CLIInvocation: Sendable, Equatable {
    public var arguments: [String]
    /// Sent on stdin, then stdin is closed. `nil` connects stdin to /dev/null.
    public var stdin: String?
    public var environment: [String: String]

    public init(arguments: [String], stdin: String? = nil, environment: [String: String] = [:]) {
        self.arguments = arguments; self.stdin = stdin; self.environment = environment
    }
}

/// Data-driven description of a supported AI coding CLI.
public struct CLIProviderSpec: Sendable {
    public let info: AIProviderInfo
    /// Executable names to look for, in order.
    public let binaryNames: [String]
    /// Command the user runs once in Terminal to log in.
    public let loginCommand: String
    /// Builds the invocation. Every spec must keep the tool from running tools or editing files.
    public let invocation: @Sendable (_ prompt: String, _ options: AIRequestOptions) -> CLIInvocation
}

public enum CLIProviders {
    public static let claude = CLIProviderSpec(
        info: AIProviderInfo(id: "claude", displayName: "Claude Code", vendor: "Anthropic",
                             privacyURL: URL(string: "https://www.anthropic.com/legal/privacy")!,
                             installURL: URL(string: "https://docs.anthropic.com/en/docs/claude-code/overview")!),
        binaryNames: ["claude"], loginCommand: "claude",
        invocation: { prompt, options in
            // Print mode, no tools at all, plan mode, nothing that would prompt, no hooks/plugins/MCP.
            var args = ["-p", "--output-format", "json", "--tools", "", "--permission-mode", "plan",
                        "--permission-prompts", "none", "--no-session-persistence", "--strict-mcp-config",
                        "--disable-slash-commands", "--safe-mode"]
            if let model = options.model { args += ["--model", model] }
            return CLIInvocation(arguments: args, stdin: prompt)
        })

    public static let codex = CLIProviderSpec(
        info: AIProviderInfo(id: "codex", displayName: "Codex CLI", vendor: "OpenAI",
                             privacyURL: URL(string: "https://openai.com/policies/privacy-policy/")!,
                             installURL: URL(string: "https://developers.openai.com/codex/cli")!),
        binaryNames: ["codex"], loginCommand: "codex",
        invocation: { prompt, options in
            var args = ["exec", "--sandbox", "read-only", "--skip-git-repo-check", "--ephemeral",
                        "--color", "never", "-c", #"approval_policy="never""#]
            if let model = options.model { args += ["--model", model] }
            args.append("-")   // prompt from stdin
            return CLIInvocation(arguments: args, stdin: prompt)
        })

    public static let antigravity = CLIProviderSpec(
        info: AIProviderInfo(id: "agy", displayName: "Antigravity CLI", vendor: "Google",
                             privacyURL: URL(string: "https://policies.google.com/privacy")!,
                             installURL: URL(string: "https://antigravity.google/")!),
        binaryNames: ["agy"], loginCommand: "agy",
        invocation: { prompt, options in
            var args = ["-p", prompt, "--mode", "plan", "--sandbox", "--output-format", "json",
                        "--print-timeout", "\(Int(options.timeout))s"]
            if let model = options.model { args += ["--model", model] }
            return CLIInvocation(arguments: args)
        })

    public static let opencode = CLIProviderSpec(
        info: AIProviderInfo(id: "opencode", displayName: "OpenCode", vendor: "OpenCode",
                             privacyURL: URL(string: "https://opencode.ai/legal/privacy-policy")!,
                             installURL: URL(string: "https://opencode.ai/")!),
        binaryNames: ["opencode"], loginCommand: "opencode auth login",
        invocation: { prompt, options in
            var args = ["run", "--agent", "plan"]
            if let model = options.model { args += ["--model", model] }
            args.append(prompt)
            // Deny every permission, globally and for the plan agent (its own rules would win otherwise).
            let config = #"{"permission":{"*":"deny"},"agent":{"plan":{"permission":{"*":"deny"}}}}"#
            return CLIInvocation(arguments: args, environment: ["OPENCODE_CONFIG_CONTENT": config])
        })

    public static let gemini = CLIProviderSpec(
        info: AIProviderInfo(id: "gemini", displayName: "Gemini CLI", vendor: "Google",
                             privacyURL: URL(string: "https://policies.google.com/privacy")!,
                             installURL: URL(string: "https://github.com/google-gemini/gemini-cli")!),
        binaryNames: ["gemini"], loginCommand: "gemini",
        invocation: { prompt, options in
            // Default approval mode: in headless runs anything needing approval is refused; no extensions.
            var args = ["--approval-mode", "default", "--extensions", "none", "--output-format", "json"]
            if let model = options.model { args += ["--model", model] }
            args += ["-p", prompt]
            return CLIInvocation(arguments: args)
        })

    public static let all: [CLIProviderSpec] = [claude, codex, antigravity, opencode, gemini]
}

/// A CLI provider found at `executable`.
public struct CLIProvider: AIProvider {
    public let spec: CLIProviderSpec
    public let executable: URL

    public init(spec: CLIProviderSpec, executable: URL) {
        self.spec = spec; self.executable = executable
    }

    public var info: AIProviderInfo { spec.info }

    /// The full launch configuration, including the minimal environment.
    public func invocation(for prompt: AIPrompt, options: AIRequestOptions) -> CLIInvocation {
        var inv = spec.invocation(prompt.text, options)
        inv.environment = CLILocator.minimalEnvironment(toolDirectory: executable.deletingLastPathComponent().path)
            .merging(inv.environment) { $1 }
        return inv
    }

    public func explain(_ prompt: AIPrompt, options: AIRequestOptions) async throws -> [AIExplanation] {
        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("Ringwise-AI-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let result = try await CLIRunner.run(executable: executable, invocation: invocation(for: prompt, options: options),
                                             workingDirectory: workDir, timeout: options.timeout)
        if result.timedOut { throw AIError.timedOut(seconds: Int(options.timeout)) }
        if let error = CLIRunner.error(for: result, spec: spec) { throw error }
        return try AIResponseParser.parse(result.stdout)
    }
}
#endif
