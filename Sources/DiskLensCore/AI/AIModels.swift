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
    /// DiskLens's own classification, e.g. "protected by macOS".
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
    public let unavailableReason: String?

    public init(provider: any AIProvider, location: String?, version: String?, unavailableReason: String? = nil) {
        self.provider = provider; self.location = location; self.version = version
        self.unavailableReason = unavailableReason
    }

    public var id: String { info.id }
    public var info: AIProviderInfo { provider.info }
    public var isUsable: Bool { unavailableReason == nil }
}

/// Errors shown to the user.
public enum AIError: Error, Equatable, LocalizedError {
    case notLoggedIn(tool: String, command: String)
    case timedOut(seconds: Int)
    case failed(String)
    case unparsable
    case unavailable(String)
    case contextTooLarge
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn(let tool, let command):
            String(localized: "\(tool) 尚未登入。請先打開「終端機」執行一次 \(command) 並完成登入，再回來重試。")
        case .timedOut(let seconds):
            String(localized: "等了 \(seconds) 秒仍沒有回應，已停止。可以在設定中調長逾時時間後重試。")
        case .failed(let message):
            String(localized: "AI 工具回報錯誤：\(message)")
        case .unparsable:
            String(localized: "看不懂 AI 的回答格式，請重試一次。")
        case .unavailable(let reason):
            reason
        case .contextTooLarge:
            String(localized: "這次的內容超過模型能處理的長度。請少選幾個項目後再試。")
        case .launchFailed(let message):
            String(localized: "無法啟動 AI 工具：\(message)")
        }
    }
}
