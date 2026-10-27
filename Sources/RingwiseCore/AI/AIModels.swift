import Foundation

/// How safe the AI thinks it is to delete an item.
public enum AISafety: String, Codable, Sendable, CaseIterable {
    case safe, caution, keep
}

/// One item explained by an AI provider. Display-only: it never triggers an action by itself.
public struct AIExplanation: Codable, Sendable, Hashable {
    public var path: String
    public var what: String
    public var owner: String?
    public var safety: AISafety
    public var impact: String
    /// 0...1
    public var confidence: Double

    public init(path: String, what: String, owner: String?, safety: AISafety, impact: String, confidence: Double) {
        self.path = path; self.what = what; self.owner = owner
        self.safety = safety; self.impact = impact; self.confidence = min(1, max(0, confidence))
    }
}

/// Metadata about one file or folder that may be sent to a provider. Never contains file contents.
public struct AIItem: Sendable, Hashable {
    public var path: String
    public var isDirectory: Bool
    public var size: Int64
    /// Recursive file count (1 for a file).
    public var itemCount: Int
    public var modified: Date?
    /// Names of the largest children (folders only), biggest first.
    public var children: [String]
    /// Ringwise's own classification, e.g. "protected by macOS".
    public var note: String?

    public init(path: String, isDirectory: Bool, size: Int64, itemCount: Int, modified: Date?,
                children: [String] = [], note: String? = nil) {
        self.path = path; self.isDirectory = isDirectory; self.size = size; self.itemCount = itemCount
        self.modified = modified; self.children = children; self.note = note
    }

    public var name: String { (path as NSString).lastPathComponent }
}

/// Static description of a provider.
public struct AIProviderInfo: Sendable, Hashable, Identifiable {
    public let id: String
    public let displayName: String
    public let vendor: String
    public let privacyURL: URL
    public let installURL: URL
    /// Runs entirely on this Mac (nothing leaves the device).
    public let isOnDevice: Bool
    /// Most items per request (always ≤ `AIPromptBuilder.maxItems`).
    public let maxItems: Int
    /// Child names listed per folder.
    public let maxChildNames: Int
    /// The provider enforces the JSON shape itself, so the prompt can skip the format spec.
    public let structuredOutput: Bool

    public init(id: String, displayName: String, vendor: String, privacyURL: URL, installURL: URL,
                isOnDevice: Bool = false, maxItems: Int = AIPromptBuilder.maxItems, maxChildNames: Int = 8,
                structuredOutput: Bool = false) {
        self.id = id; self.displayName = displayName; self.vendor = vendor
        self.privacyURL = privacyURL; self.installURL = installURL; self.isOnDevice = isOnDevice
        self.maxItems = min(maxItems, AIPromptBuilder.maxItems); self.maxChildNames = maxChildNames
        self.structuredOutput = structuredOutput
    }
}

/// Per-request knobs chosen in Settings.
public struct AIRequestOptions: Sendable, Equatable {
    /// Model override; `nil` uses the provider's default.
    public var model: String?
    public var timeout: TimeInterval

    public init(model: String? = nil, timeout: TimeInterval = 90) {
        let trimmed = model?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = trimmed?.isEmpty == false ? trimmed : nil
        self.timeout = timeout
    }
}

/// Something that can explain items. CLI tools and Apple's on-device model implement it.
public protocol AIProvider: Sendable {
    var info: AIProviderInfo { get }
    func explain(_ prompt: AIPrompt, options: AIRequestOptions) async throws -> [AIExplanation]
}

/// A provider found on this Mac, with where it lives and whether it can be used right now.
public struct AIDetectedProvider: Sendable, Identifiable {
    public let provider: any AIProvider
    /// Executable path for CLI tools; `nil` for built-in providers.
    public let location: String?
    public let version: String?
    /// Why the provider cannot be used right now (e.g. Apple Intelligence is off), or `nil`.
    public let unavailableReason: AIUnavailableReason?

    public init(provider: any AIProvider, location: String?, version: String?, unavailableReason: AIUnavailableReason? = nil) {
        self.provider = provider; self.location = location; self.version = version
        self.unavailableReason = unavailableReason
    }

    public var id: String { info.id }
    public var info: AIProviderInfo { provider.info }
    public var isUsable: Bool { unavailableReason == nil }
}

/// Why a provider cannot be used right now. The app turns these into localized messages.
public enum AIUnavailableReason: Sendable, Equatable {
    /// This Mac does not support Apple Intelligence.
    case deviceNotEligible
    /// Apple Intelligence is turned off in System Settings.
    case appleIntelligenceNotEnabled
    /// The on-device model is still downloading or being prepared.
    case modelNotReady
    /// The on-device model is unavailable for another reason.
    case modelUnavailable
    /// This macOS version has no on-device model (FoundationModels missing).
    case unsupportedOS
    /// The on-device model does not support the current language.
    case unsupportedLanguage
}

/// Errors shown to the user.
///
/// Core carries no user-facing text: the app localizes these (`AIError.message` in the app target).
/// `errorDescription` is a plain English fallback for logs and command-line tools.
public enum AIError: Error, Equatable, LocalizedError {
    case notLoggedIn(tool: String, command: String)
    case timedOut(seconds: Int)
    /// The tool reported an error; the payload is the tool's own output.
    case failed(String)
    /// The tool exited with a non-zero status and printed nothing useful.
    case exitStatus(Int32)
    /// The tool printed nothing.
    case noOutput
    /// The model refused to answer (guardrails).
    case refused
    /// The model is busy (rate-limited or another request is running).
    case busy
    case unparsable
    case unavailable(AIUnavailableReason)
    case contextTooLarge
    /// The tool could not be launched; the payload is the system's error message.
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn(let tool, let command): "\(tool) is not signed in. Run \(command) in Terminal first."
        case .timedOut(let seconds): "No response after \(seconds) seconds."
        case .failed(let message): "The AI tool reported an error: \(message)"
        case .exitStatus(let status): "The AI tool exited with status \(status)."
        case .noOutput: "The AI tool produced no output."
        case .refused: "The model declined to answer this request."
        case .busy: "The model is busy."
        case .unparsable: "The AI's answer could not be read."
        case .unavailable(let reason): "The model is unavailable (\(reason))."
        case .contextTooLarge: "The request is too long for the model."
        case .launchFailed(let message): "Could not launch the AI tool: \(message)"
        }
    }
}
