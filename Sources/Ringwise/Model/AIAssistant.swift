import SwiftUI
import Observation
import RingwiseCore

/// An item being explained: what is sent (metadata only) and the tree node it came from.
struct AIRequestItem: Identifiable, Sendable {
    let item: AIItem
    let node: NodeID
    var id: String { item.path }
}

/// A request waiting for the user's consent.
struct AIConsentRequest: Identifiable {
    let id = UUID()
    let provider: AIDetectedProvider
    let items: [AIRequestItem]
    let prompt: AIPrompt
    let totalSelected: Int
}

/// State of the results inspector.
struct AIPanel {
    var items: [AIRequestItem] = []
    var answers: [String: AIExplanation] = [:]
    var providerName = ""
    var totalSelected = 0
    var isLoading = false
    var fromCache = false
    var error: String?
    var notice: String?
}

/// AI explanations: settings, provider detection, consent, requests and the answer cache.
///
/// Ringwise itself never sends anything over the network: it only launches a tool the user
/// installed (or uses Apple's on-device model), with metadata — never file contents.
@MainActor @Observable
final class AIAssistant {
    private enum Key {
        static let enabled = "ai.enabled", provider = "ai.provider", model = "ai.model"
        static let timeout = "ai.timeout", consents = "ai.consents"
    }
    @ObservationIgnored private let defaults = UserDefaults.standard

    // MARK: Settings

    var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Key.enabled) } }
    /// Chosen provider id; `nil` follows the default (Apple on-device, else the first CLI).
    var selectedProviderID: String? { didSet { defaults.set(selectedProviderID, forKey: Key.provider) } }
    var modelOverride: String { didSet { defaults.set(modelOverride, forKey: Key.model) } }
    var timeout: Double { didSet { defaults.set(timeout, forKey: Key.timeout) } }
    /// Provider id → date the user agreed.
    private(set) var consents: [String: Date] {
        didSet { defaults.set(consents.mapValues { $0.timeIntervalSince1970 }, forKey: Key.consents) }
    }

    // MARK: Providers

    private(set) var providers: [AIDetectedProvider] = []
    private(set) var isDetecting = false
    private(set) var hasDetected = false

    var currentProvider: AIDetectedProvider? {
        if let id = selectedProviderID, let chosen = providers.first(where: { $0.id == id && $0.isUsable }) { return chosen }
        return AIProviderRegistry.defaultProvider(in: providers)
    }

    // MARK: Presentation

    var consentRequest: AIConsentRequest?
    var showingNoProvider = false
    var showingPanel = false
    var panel = AIPanel()
    private(set) var cachedCount = 0

    @ObservationIgnored private var cache = AICache.load()
    @ObservationIgnored private var runTask: Task<Void, Never>?

    init() {
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        selectedProviderID = defaults.string(forKey: Key.provider)
        modelOverride = defaults.string(forKey: Key.model) ?? ""
        timeout = defaults.object(forKey: Key.timeout) as? Double ?? 90
        consents = (defaults.dictionary(forKey: Key.consents) as? [String: Double] ?? [:])
            .mapValues { Date(timeIntervalSince1970: $0) }
        cachedCount = cache.entries.count
    }

    // MARK: Detection

    func detectProviders() async {
        guard !isDetecting else { return }
        isDetecting = true
        providers = await Task.detached(priority: .userInitiated) { await AIProviderRegistry.detect() }.value
        isDetecting = false
        hasDetected = true
    }

    // MARK: Consent

    func consentDate(for id: String) -> Date? { consents[id] }

    func revokeConsent(for id: String) { consents[id] = nil }

    func acceptConsent(_ request: AIConsentRequest) {
        consents[request.provider.id] = Date()
        consentRequest = nil
        // Whatever the user agreed to becomes the explicit choice.
        selectedProviderID = request.provider.id
        run(request.items, provider: request.provider, totalSelected: request.totalSelected, force: false)
    }

    func declineConsent() {
        consentRequest = nil
    }

    // MARK: Requests

    /// Explains `items` (biggest first). Asks for consent first if this provider has none yet.
    func ask(_ items: [AIRequestItem], totalSelected: Int) {
        guard !items.isEmpty else { return }
        Task {
            if !hasDetected { await detectProviders() }
            guard isEnabled else {
                showPanel(items: [], totalSelected: totalSelected, providerName: "")
                panel.error = String(localized: "AI 說明已在設定中關閉。可以到「設定」（⌘,）的 AI 區段重新開啟。")
                return
            }
            guard let provider = currentProvider else {
                showingNoProvider = true
                return
            }
            let capped = Array(items.sorted { $0.item.size > $1.item.size }.prefix(provider.info.maxItems))
            if consents[provider.id] == nil {
                consentRequest = AIConsentRequest(provider: provider, items: capped,
                                                  prompt: AIPromptBuilder.build(items: capped.map(\.item), info: provider.info, language: AILanguage.current),
                                                  totalSelected: totalSelected)
                return
            }
            run(capped, provider: provider, totalSelected: totalSelected, force: false)
        }
    }

    /// Asks again for the items in the panel, ignoring the cache.
    func askAgain() {
        guard let provider = currentProvider, !panel.items.isEmpty else { return }
        if consents[provider.id] == nil {
            ask(panel.items, totalSelected: panel.totalSelected)
        } else {
            run(panel.items, provider: provider, totalSelected: panel.totalSelected, force: true)
        }
    }

    func cancel() {
        runTask?.cancel()
        runTask = nil
        panel.isLoading = false
    }

    private func run(_ items: [AIRequestItem], provider: AIDetectedProvider, totalSelected: Int, force: Bool) {
        runTask?.cancel()
        showPanel(items: items, totalSelected: totalSelected, providerName: provider.info.displayName)
        let omitted = totalSelected - items.count
        if omitted > 0 {
            panel.notice = String(localized: "共選取 \(totalSelected) 個項目，只說明最大的 \(items.count) 個。")
        }

        var missing: [AIRequestItem] = []
        for entry in items {
            if !force, let hit = cache.lookup(entry.item, providerID: provider.id) {
                panel.answers[entry.item.path] = hit.explanation
            } else {
                missing.append(entry)
            }
        }
        panel.fromCache = missing.isEmpty
        guard !missing.isEmpty else { return }

        panel.isLoading = true
        let prompt = AIPromptBuilder.build(items: missing.map(\.item), info: provider.info, language: AILanguage.current)
        let options = AIRequestOptions(model: provider.info.isOnDevice ? nil : modelOverride, timeout: timeout)
        let backend = provider.provider
        runTask = Task {
            do {
                let answers = try await Task.detached(priority: .userInitiated) {
                    try await backend.explain(prompt, options: options)
                }.valueCancellingOnCancel()
                guard !Task.isCancelled else { return }
                let matched = AIResponseParser.match(answers, to: prompt.items)
                for item in prompt.items {
                    guard let answer = matched[item.path] else { continue }
                    panel.answers[item.path] = answer
                    cache.store(answer, for: item, providerID: provider.id)
                }
                if matched.isEmpty { panel.error = AIError.unparsable.message }
                saveCache()
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                panel.error = userMessage(for: error)
            }
            panel.isLoading = false
        }
    }

    private func showPanel(items: [AIRequestItem], totalSelected: Int, providerName: String) {
        panel = AIPanel(items: items, providerName: providerName, totalSelected: totalSelected)
        showingPanel = true
    }

    // MARK: Cache

    func clearCache() {
        cache.removeAll()
        saveCache()
    }

    private func saveCache() {
        cachedCount = cache.entries.count
        let snapshot = cache
        Task.detached(priority: .utility) { try? snapshot.save() }
    }

    // MARK: Demo

    /// Fills the panel with sample answers for UI checks (`RINGWISE_DEMO_AI=results`).
    func showDemoResults(_ items: [AIRequestItem]) {
        // Screenshot mode shows the App Store build's provider, with answers matching the demo caches.
        let demo = DemoData.isEnabled
        showPanel(items: items, totalSelected: items.count + 3, providerName: demo ? "Apple Intelligence" : "Claude Code")
        panel.notice = String(localized: "共選取 \(items.count + 3) 個項目，只說明最大的 \(items.count) 個。")
        let samples: [(AISafety, String, String?, String)] = demo ? [
            (.caution, String(localized: "Xcode 的索引與建置快取。"), "Xcode", String(localized: "下次開啟專案時會重新建立索引，會花比較久。")),
            (.safe, String(localized: "Safari 暫存的網頁資料，用來加快載入速度。"), "Safari", String(localized: "會自動重新產生，網頁第一次開啟可能稍慢。")),
            (.safe, String(localized: "「音樂」App 下載的專輯封面快取。"), String(localized: "音樂"), String(localized: "需要時會重新下載。")),
        ] : [
            (.safe, "App 暫存的快取檔案，用來加快載入速度。", "Apple", "會自動重新產生，第一次開啟可能稍慢。"),
            (.caution, "開發工具的建置產物與索引資料。", "Xcode", "下次建置需要重新編譯，會花比較久。"),
            (.keep, "App 的設定與使用者資料。", nil, "可能遺失設定或登入狀態。"),
        ]
        for (i, entry) in items.enumerated() {
            let s = samples[i % samples.count]
            panel.answers[entry.item.path] = AIExplanation(path: entry.item.path, what: s.1, owner: s.2,
                                                           safety: s.0, impact: s.3, confidence: 0.6 + Double(i % 4) / 10)
        }
    }
}

private extension Task where Failure == Error {
    /// `value`, cancelling this unstructured task when the awaiting task is cancelled.
    func valueCancellingOnCancel() async throws -> Success {
        try await withTaskCancellationHandler { try await value } onCancel: { cancel() }
    }
}
