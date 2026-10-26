import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device model (FoundationModels). Offline, free and private: nothing leaves the Mac.
/// Its context window is small, so requests are capped at 10 items with 3 child names each.
public struct AppleOnDeviceProvider: AIProvider {
    public static let info = AIProviderInfo(
        id: "apple", displayName: "Apple Intelligence", vendor: "Apple",
        privacyURL: URL(string: "https://www.apple.com/legal/privacy/data/en/intelligence-engine/")!,
        installURL: URL(string: "https://support.apple.com/en-us/121115")!,
        isOnDevice: true, maxItems: 10, maxChildNames: 3, structuredOutput: true)

    public init() {}

    public var info: AIProviderInfo { Self.info }

    /// Why the model cannot be used right now, or `nil` when it is ready.
    public static var unavailableReason: String? {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return String(localized: "這台 Mac 不支援 Apple Intelligence。")
        case .unavailable(.appleIntelligenceNotEnabled):
            return String(localized: "Apple Intelligence 尚未開啟。請到「系統設定」>「Apple Intelligence 與 Siri」開啟後再試。")
        case .unavailable(.modelNotReady):
            return String(localized: "Apple 的裝置端模型還在下載或準備中，請稍後再試。")
        case .unavailable:
            return String(localized: "Apple 的裝置端模型目前無法使用。")
        }
        #else
        return String(localized: "這個版本的 macOS 不提供 Apple 裝置端模型。")
        #endif
    }

    public func explain(_ prompt: AIPrompt, options: AIRequestOptions) async throws -> [AIExplanation] {
        #if canImport(FoundationModels)
        if let reason = Self.unavailableReason { throw AIError.unavailable(reason) }
        let session = LanguageModelSession(instructions: """
            You explain macOS files and folders from metadata only and judge whether deleting them is safe. \
            Be concise and honest about uncertainty.
            """)
        do {
            let answer = try await withTimeout(options.timeout) {
                try await session.respond(to: prompt.text, generating: GeneratedAnswer.self).content
            }
            let explanations = answer.items.map {
                AIExplanation(path: $0.path, what: $0.what, owner: $0.owner.flatMap { $0.isEmpty ? nil : $0 },
                              safety: AISafety(rawValue: $0.safety.rawValue) ?? .caution,
                              impact: $0.impact, confidence: $0.confidence)
            }
            guard !explanations.isEmpty else { throw AIError.unparsable }
            return explanations
        } catch let error as LanguageModelSession.GenerationError {
            throw Self.map(error)
        }
        #else
        throw AIError.unavailable(Self.unavailableReason ?? "")
        #endif
    }

    #if canImport(FoundationModels)
    static func map(_ error: LanguageModelSession.GenerationError) -> AIError {
        switch error {
        case .exceededContextWindowSize:
            return .contextTooLarge
        case .assetsUnavailable:
            return .unavailable(String(localized: "Apple 的裝置端模型還在下載或準備中，請稍後再試。"))
        case .guardrailViolation, .refusal:
            return .failed(String(localized: "Apple 的模型拒絕回答這個請求。"))
        case .unsupportedLanguageOrLocale:
            return .unavailable(String(localized: "Apple 的裝置端模型尚不支援目前的語言。"))
        case .rateLimited, .concurrentRequests:
            return .failed(String(localized: "模型正忙，請稍後再試。"))
        default:
            return .failed(error.localizedDescription)
        }
    }
    #endif
}

#if canImport(FoundationModels)
@Generable
struct GeneratedAnswer {
    @Guide(description: "One entry per item, in the same order as the list")
    var items: [GeneratedItem]
}

@Generable
struct GeneratedItem {
    @Guide(description: "The exact path from the list")
    var path: String
    @Guide(description: "What it most likely is, 1-2 sentences")
    var what: String
    @Guide(description: "App or vendor that created it, if known")
    var owner: String?
    var safety: GeneratedSafety
    @Guide(description: "What happens if it is deleted")
    var impact: String
    @Guide(description: "Confidence from 0 to 1", .range(0...1))
    var confidence: Double
}

@Generable
enum GeneratedSafety: String {
    case safe, caution, keep
}
#endif

/// Runs `operation`, throwing `AIError.timedOut` if it takes longer than `seconds`.
func withTimeout<T: Sendable>(_ seconds: TimeInterval, _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw AIError.timedOut(seconds: Int(seconds))
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}
