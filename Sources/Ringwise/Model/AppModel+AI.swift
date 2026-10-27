import Foundation
import RingwiseCore

/// "Ask AI: what is this?" — turns a selection into metadata-only request items.
extension AppModel {
    func askAI(_ ids: Set<NodeID>) {
        guard let tree else { return }
        let targets = tree.topLevelTargets(ids)
        let items = targets.prefix(AIPromptBuilder.maxItems).map { AIRequestItem(item: tree.aiItem($0), node: $0) }
        ai.ask(Array(items), totalSelected: targets.count)
    }

    /// Selects an explained item in the folder browser, if it still exists.
    func selectAIItem(_ node: NodeID) {
        guard let tree, tree.isLive(node), let parent = tree.parent(node) else { return }
        searchText = ""
        sidebar = .folders
        open(parent)
        selection = [node]
    }
}

enum AILanguage {
    /// Language the app's UI is shown in (the localization the system picked for this app), so
    /// answers match it. A bare binary without .lproj folders shows the zh-Hant source strings.
    static var current: String {
        guard Bundle.main.localizations.contains(where: { $0 != "Base" }),
              let picked = Bundle.main.preferredLocalizations.first else { return "zh-Hant-TW" }
        switch picked {
        case "zh-Hant": return "zh-Hant-TW"     // the source strings are written for Taiwan
        case "zh-Hans": return "zh-Hans-CN"     // translated for Mainland China
        default: return picked
        }
    }
}

extension FileTree {
    /// Path, kind, size, counts, date, the biggest child names and Ringwise's own note. Never contents.
    func aiItem(_ id: NodeID) -> AIItem {
        let path = path(id)
        var note: String?
        switch FileActions.protection(for: path) {
        case .blocked: note = String(localized: "受 macOS 保護，Ringwise 不允許刪除")
        case .warn(let reason): note = reason.message
        case .allowed: break
        }
        if isDataless(id) { note = String(localized: "iCloud 雲端佔位檔，內容不在這台 Mac 上") }
        return AIItem(path: path, isDirectory: isDirectory(id), size: size(id), itemCount: fileCount(id),
                      modified: modified(id), children: isDirectory(id) ? children(id).prefix(8).map { name($0) } : [],
                      note: note)
    }
}

/// Debug hook for UI checks without synthetic input: `RINGWISE_DEMO_AI=consent|results|noprovider|settings`
/// (with `RINGWISE_AUTOSCAN`), optionally `RINGWISE_DEMO_AI_PROVIDER=<id>` for the consent sheet.
@MainActor
enum AIDemo {
    static func run(_ model: AppModel, openSettings: () -> Void) async {
        let env = ProcessInfo.processInfo.environment
        guard let mode = env["RINGWISE_DEMO_AI"], let tree = model.tree else { return }
        let ids = model.folderRows.prefix(4).map(\.id)
        let items = ids.map { AIRequestItem(item: tree.aiItem($0), node: $0) }
        model.selection = Set(ids)
        let ai = model.ai
        await ai.detectProviders()
        switch mode {
        case "consent":
            let wanted = env["RINGWISE_DEMO_AI_PROVIDER"]
            guard let provider = ai.providers.first(where: { $0.id == wanted }) ?? ai.currentProvider ?? ai.providers.first else { return }
            let capped = Array(items.prefix(provider.info.maxItems))
            ai.consentRequest = AIConsentRequest(provider: provider, items: capped,
                                                 prompt: AIPromptBuilder.build(items: capped.map(\.item), info: provider.info, language: AILanguage.current),
                                                 totalSelected: items.count)
        case "results":
            ai.showDemoResults(Array(items.prefix(3)))
        case "noprovider":
            ai.showingNoProvider = true
        case "settings":
            openSettings()
        default:
            break
        }
    }
}
