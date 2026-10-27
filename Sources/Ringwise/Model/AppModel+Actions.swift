import AppKit
import RingwiseCore

/// File actions: reveal, copy path, trash, move. Nothing is ever deleted permanently.
extension AppModel {
    func reveal(_ ids: Set<NodeID>) {
        guard let tree else { return }
        let urls = tree.topLevelTargets(ids).prefix(200).map { tree.url($0) }
        if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(Array(urls)) }
    }

    func copyPaths(_ ids: Set<NodeID>) {
        guard let tree else { return }
        let paths = ids.filter { tree.isLive($0) }.sorted { tree.size($0) > tree.size($1) }.map { tree.path($0) }
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }

    /// Why `ids` cannot be trashed or moved, or `nil` if at least one item can be.
    /// Very large selections are not pre-checked; protected items are skipped at request time.
    func blockReason(for ids: Set<NodeID>) -> String? {
        guard let tree else { return String(localized: "尚未掃描。") }
        guard ids.count <= 2_000 else { return nil }
        let targets = tree.topLevelTargets(ids)
        guard !targets.isEmpty else { return String(localized: "沒有可處理的項目。") }
        var firstReason: String?
        for id in targets {
            if case .blocked(let why) = FileActions.protection(for: tree.path(id)) {
                if firstReason == nil { firstReason = why.message }
            } else {
                return nil
            }
        }
        return firstReason
    }

    // MARK: Trash

    /// Prepares a confirmation for moving `ids` to the Trash.
    func requestTrash(_ ids: Set<NodeID>) {
        guard let tree, !isPerformingAction else { return }
        var allowed: [NodeID] = []
        var warnings: [String] = []
        var skipped = 0
        var blockedReason: String?
        for id in tree.topLevelTargets(ids) {
            switch FileActions.protection(for: tree.path(id)) {
            case .allowed:
                allowed.append(id)
            case .warn(let reason):
                allowed.append(id)
                if !warnings.contains(reason.message) { warnings.append(reason.message) }
            case .blocked(let why):
                skipped += 1
                blockedReason = blockedReason ?? why.message
            }
        }
        guard !allowed.isEmpty else {
            if let blockedReason { errorMessage = blockedReason }
            return
        }
        pendingTrash = TrashRequest(targets: allowed,
                                    totalSize: allowed.reduce(0) { $0 + tree.size($1) },
                                    warnings: warnings, skipped: skipped)
    }

    func confirmTrash(_ request: TrashRequest) {
        pendingTrash = nil
        perform(on: request.targets, failureTitle: String(localized: "無法丟到垃圾桶")) { url in
            try FileActions.trash(url)
        }
    }

    // MARK: Move

    /// Asks for a destination folder and moves `ids` there.
    func requestMove(_ ids: Set<NodeID>) {
        guard let tree, !isPerformingAction else { return }
        let targets = tree.topLevelTargets(ids).filter {
            if case .blocked = FileActions.protection(for: tree.path($0)) { return false }
            return true
        }
        guard !targets.isEmpty else {
            errorMessage = blockReason(for: ids) ?? String(localized: "沒有可搬移的項目。")
            return
        }
        let message = targets.count == 1
            ? String(localized: "將「\(tree.name(targets[0]))」搬移到…")
            : String(localized: "將 \(targets.count) 個項目（\(ByteFormat.string(targets.reduce(0) { $0 + tree.size($1) }))）搬移到…")
        guard let destination = Panels.chooseFolder(message: message, prompt: String(localized: "搬移到這裡")) else { return }
        perform(on: targets, failureTitle: String(localized: "無法搬移")) { url in
            if destination.standardizedFileURL.path.hasPrefix(url.standardizedFileURL.path + "/")
                || destination.standardizedFileURL == url.deletingLastPathComponent().standardizedFileURL {
                throw CocoaError(.fileWriteFileExists, userInfo: [NSLocalizedDescriptionKey: String(localized: "目的地與原位置相同或位於其內。")])
            }
            _ = try FileActions.move(url, into: destination)
        }
    }

    // MARK: Shared

    /// Runs `operation` for each target off the main thread, then removes the successful ones from the tree.
    private func perform(on targets: [NodeID], failureTitle: String,
                         operation: @escaping @Sendable (URL) throws -> Void) {
        guard let tree else { return }
        let items = targets.map { (id: $0, url: tree.url($0)) }
        isPerformingAction = true
        Task {
            let outcome = await Task.detached(priority: .userInitiated) { () -> ActionOutcome in
                var outcome = ActionOutcome()
                for item in items {
                    do {
                        try operation(item.url)
                        outcome.done.append(item.id)
                    } catch {
                        outcome.errors.append(String(localized: "\(item.url.lastPathComponent)：\(userMessage(for: error))"))
                    }
                }
                return outcome
            }.value
            isPerformingAction = false
            applyRemoval(outcome.done)
            if !outcome.errors.isEmpty {
                let shown = outcome.errors.prefix(8).joined(separator: "\n")
                let more = outcome.errors.count > 8 ? "\n" + String(localized: "…另有 \(outcome.errors.count - 8) 個錯誤") : ""
                errorMessage = String(localized: "\(failureTitle)：\n\(shown)\(more)")
            }
        }
    }
}
