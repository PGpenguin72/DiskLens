#if !APP_STORE
import Foundation
import os

/// Output of a finished CLI run.
public struct CLIResult: Sendable {
    public var status: Int32
    public var stdout: String
    public var stderr: String
    public var timedOut: Bool
}

/// Runs a CLI as a child `Process` (no shell), with a timeout and task cancellation.
public enum CLIRunner {
    public static func run(executable: URL, invocation: CLIInvocation, workingDirectory: URL?,
                           timeout: TimeInterval) async throws -> CLIResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = invocation.arguments
        process.environment = invocation.environment.isEmpty ? nil : invocation.environment
        if let workingDirectory { process.currentDirectoryURL = workingDirectory }
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        let input = invocation.stdin == nil ? nil : Pipe()
        process.standardInput = input ?? FileHandle.nullDevice

        // started / cancelled / timed out, shared between the caller, the timer and the cancel handler.
        let state = OSAllocatedUnfairLock(initialState: (started: false, cancelled: false, timedOut: false))

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLIResult, Error>) in
                let group = DispatchGroup()
                let collected = OSAllocatedUnfairLock(initialState: (out: Data(), err: Data()))
                for (pipe, isOut) in [(out, true), (err, false)] {
                    group.enter()
                    DispatchQueue.global(qos: .userInitiated).async {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        collected.withLock { if isOut { $0.out = data } else { $0.err = data } }
                        group.leave()
                    }
                }
                group.enter()
                process.terminationHandler = { _ in group.leave() }

                let proceed = state.withLock { s -> Bool in
                    guard !s.cancelled else { return false }
                    s.started = true
                    return true
                }
                do {
                    guard proceed else { throw CancellationError() }
                    try process.run()
                } catch {
                    // Unblock the readers, then report.
                    try? out.fileHandleForWriting.close()
                    try? err.fileHandleForWriting.close()
                    continuation.resume(throwing: error is CancellationError ? error : AIError.launchFailed(error.localizedDescription))
                    return
                }
                // Our copies of the write ends must close, or the readers never see EOF.
                try? out.fileHandleForWriting.close()
                try? err.fileHandleForWriting.close()

                if let input, let text = invocation.stdin {
                    DispatchQueue.global(qos: .userInitiated).async {
                        try? input.fileHandleForWriting.write(contentsOf: Data(text.utf8))
                        try? input.fileHandleForWriting.close()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    guard process.isRunning else { return }
                    state.withLock { $0.timedOut = true }
                    terminate(process)
                }
                group.notify(queue: .global()) {
                    let (o, e) = collected.withLock { ($0.out, $0.err) }
                    let s = state.withLock { $0 }
                    if s.cancelled { continuation.resume(throwing: CancellationError()); return }
                    continuation.resume(returning: CLIResult(status: process.terminationStatus,
                                                             stdout: String(decoding: o, as: UTF8.self),
                                                             stderr: String(decoding: e, as: UTF8.self),
                                                             timedOut: s.timedOut))
                }
            }
        } onCancel: {
            let started = state.withLock { s -> Bool in s.cancelled = true; return s.started }
            if started { terminate(process) }
        }
    }

    /// SIGTERM, then SIGKILL if the process is still alive two seconds later.
    private static func terminate(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if process.isRunning { kill(pid, SIGKILL) }
        }
    }

    /// Maps a failed run to a friendly error, or `nil` when the run succeeded.
    public static func error(for result: CLIResult, spec: CLIProviderSpec) -> AIError? {
        let stderr = stripANSI(result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = (stderr + "\n" + stdout).lowercased()
        let loginHints = ["not logged in", "please log in", "please run /login", "unauthorized", "authentication error",
                          "authentication failed", "not authenticated", "invalid api key", "auth error", "login required"]
        if result.status != 0 || stdout.isEmpty {
            if loginHints.contains(where: combined.contains) {
                return .notLoggedIn(tool: spec.info.displayName, command: spec.loginCommand)
            }
            // Envelopes such as Claude's report the error in stdout.
            if result.status != 0, (try? AIResponseParser.parse(stdout)) == nil {
                let message = lastLines(stderr.isEmpty ? stdout : stderr)
                return message.isEmpty ? .exitStatus(result.status) : .failed(message)
            }
            if stdout.isEmpty { return lastLines(stderr).isEmpty ? .noOutput : .failed(lastLines(stderr)) }
        }
        return nil
    }

    static func stripANSI(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression)
    }

    private static func lastLines(_ s: String) -> String {
        String(s.split(separator: "\n").suffix(4).joined(separator: "\n").suffix(500))
    }
}

/// Finds CLI tools. GUI apps don't inherit the shell's PATH, so common install folders are searched
/// first, then a login shell is asked as a fallback.
public enum CLILocator {
    public static var searchDirectories: [String] {
        let home = NSHomeDirectory()
        return [home + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", home + "/.npm-global/bin",
                home + "/.bun/bin", home + "/.claude/local", home + "/.opencode/bin", home + "/.volta/bin"]
    }

    public static func locate(_ names: [String]) async -> URL? {
        let fm = FileManager.default
        for name in names {
            for dir in searchDirectories {
                let path = dir + "/" + name
                if fm.isExecutableFile(atPath: path) { return URL(fileURLWithPath: path) }
            }
        }
        for name in names where name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) {
            if let path = await loginShellLookup(name) { return URL(fileURLWithPath: path) }
        }
        return nil
    }

    /// `command -v <name>` in a login shell, with a timeout. `name` is passed as `$1`, never interpolated.
    static func loginShellLookup(_ name: String) async -> String? {
        let inv = CLIInvocation(arguments: ["-lc", #"command -v -- "$1""#, "zsh", name])
        guard let result = try? await CLIRunner.run(executable: URL(fileURLWithPath: "/bin/zsh"), invocation: inv,
                                                    workingDirectory: nil, timeout: 4),
              !result.timedOut,
              let line = result.stdout.split(separator: "\n").last.map(String.init),
              line.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: line) else { return nil }
        return line
    }

    /// First line of `<tool> --version`, with a timeout.
    public static func version(of executable: URL) async -> String? {
        let env = minimalEnvironment(toolDirectory: executable.deletingLastPathComponent().path)
        guard let result = try? await CLIRunner.run(executable: executable,
                                                    invocation: CLIInvocation(arguments: ["--version"], environment: env),
                                                    workingDirectory: nil, timeout: 6),
              result.status == 0, !result.timedOut else { return nil }
        let line = CLIRunner.stripANSI(result.stdout).split(separator: "\n").first.map { $0.trimmingCharacters(in: .whitespaces) }
        return line?.isEmpty == false ? line : nil
    }

    /// PATH with the tool's folder and common install folders, plus HOME and a few basics.
    public static func minimalEnvironment(toolDirectory: String) -> [String: String] {
        let system = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        var path: [String] = []
        for dir in [toolDirectory] + searchDirectories + system where !path.contains(dir) { path.append(dir) }
        let parent = ProcessInfo.processInfo.environment
        var env = ["PATH": path.joined(separator: ":"), "HOME": NSHomeDirectory(), "NO_COLOR": "1", "TERM": "dumb"]
        for key in ["USER", "LOGNAME", "TMPDIR", "LANG", "SHELL"] { env[key] = parent[key] }
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }
        return env
    }
}
#endif
