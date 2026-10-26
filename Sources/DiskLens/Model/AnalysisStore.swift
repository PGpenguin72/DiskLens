import AppKit
import Observation
import DiskLensCore

/// Results of the analysis passes (apps, file types, cleanup), computed off the main thread.
///
/// Started after each scan; views call `refreshIfNeeded` when they appear, which recomputes only
/// if the tree changed (trash / move) since the last run.
@MainActor @Observable
final class AnalysisStore {
    private(set) var apps: AppAttributionReport?
    private(set) var fileTypes: FileTypeReport?
    private(set) var cleanup: [CleanupMatch]?
    /// Combined reclaimable size, overlapping rules counted once.
    private(set) var cleanupTotal: Int64 = 0
    private(set) var isRunning = false
    /// Seconds each pass took in the last run (catalog, apps, fileTypes, cleanup).
    private(set) var timings: [String: Double] = [:]

    // View state kept across sidebar switches.
    var selectedApp: String?
    var selectedLeftover: String?
    var showingLeftovers = false
    var selectedCategory: FileCategory = .video
    var selectedRule: CleanupRuleID?
    var categorySort = FileRow.defaultSort {
        didSet { categoryRows = categoryRows.sorted(by: categorySort) }
    }
    var ruleSort = FileRow.defaultSort {
        didSet { ruleRows = ruleRows.sorted(by: ruleSort) }
    }
    private(set) var categoryRows: [FileRow] = []
    private(set) var ruleRows: [FileRow] = []

    @ObservationIgnored private var computedRevision = -1
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var catalog: [InstalledApp]?
    @ObservationIgnored private weak var tree: FileTree?

    func reset() {
        task?.cancel()
        apps = nil; fileTypes = nil; cleanup = nil; cleanupTotal = 0
        categoryRows = []; ruleRows = []
        selectedApp = nil; selectedLeftover = nil; selectedRule = nil
        computedRevision = -1
        isRunning = false
        tree = nil
    }

    /// Recomputes everything if `revision` differs from the last computed one.
    func refreshIfNeeded(tree: FileTree?, revision: Int) {
        guard let tree, revision != computedRevision || self.tree !== tree else { return }
        computedRevision = revision
        self.tree = tree
        task?.cancel()
        isRunning = true
        let cached = catalog
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        task = Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Output in
                var timings: [String: Double] = [:]
                func timed<T>(_ key: String, _ work: () -> T) -> T {
                    let t0 = Date(); defer { timings[key] = Date().timeIntervalSince(t0) }
                    return work()
                }
                let catalog = cached ?? timed("catalog") { AppCatalog.load(tree: tree) }
                // File types run alongside the app/cleanup passes.
                async let types = { () -> (FileTypeReport, Double) in
                    let t0 = Date()
                    let r = FileCategorizer.analyze(tree)
                    return (r, Date().timeIntervalSince(t0))
                }()
                let apps = timed("apps") { AppAttribution.analyze(tree: tree, apps: catalog, extraKnownBundleIDs: running) }
                let cleanup = timed("cleanup") { CleanupRules.analyze(tree: tree, leftovers: apps.leftovers) }
                let total = CleanupRules.uniqueTotal(cleanup, in: tree)
                let (fileTypes, typesTime) = await types
                timings["fileTypes"] = typesTime
                return Output(catalog: catalog, apps: apps, fileTypes: fileTypes, cleanup: cleanup, cleanupTotal: total, timings: timings)
            }.value
            guard !Task.isCancelled else { return }
            catalog = result.catalog
            apps = result.apps
            fileTypes = result.fileTypes
            cleanup = result.cleanup
            cleanupTotal = result.cleanupTotal
            timings = result.timings
            isRunning = false
            if selectedApp == nil { selectedApp = result.apps.apps.first?.id }
            if selectedLeftover == nil { selectedLeftover = result.apps.leftovers.first?.id }
            if selectedRule == nil || !result.cleanup.contains(where: { $0.rule == selectedRule }) {
                selectedRule = result.cleanup.first?.rule
            }
            if selectedCategory == .video, let biggest = result.fileTypes.totals.max(by: { $0.size < $1.size }), result.fileTypes.total(.video).size == 0 {
                selectedCategory = biggest.category
            }
            rebuildCategoryRows()
            rebuildRuleRows()
        }
    }

    private struct Output: Sendable {
        let catalog: [InstalledApp]
        let apps: AppAttributionReport
        let fileTypes: FileTypeReport
        let cleanup: [CleanupMatch]
        let cleanupTotal: Int64
        let timings: [String: Double]
    }

    // MARK: Derived rows

    func selectCategory(_ category: FileCategory) {
        selectedCategory = category
        rebuildCategoryRows()
    }

    func selectRule(_ rule: CleanupRuleID) {
        selectedRule = rule
        rebuildRuleRows()
    }

    private func rebuildCategoryRows() {
        guard let tree, let fileTypes else { categoryRows = []; return }
        categoryRows = FileRow.list(fileTypes.total(selectedCategory).largest.filter { tree.isLive($0) }, in: tree)
            .sorted(by: categorySort)
    }

    private func rebuildRuleRows() {
        guard let tree, let match = cleanup?.first(where: { $0.rule == selectedRule }) else { ruleRows = []; return }
        ruleRows = FileRow.list(match.items, in: tree).sorted(by: ruleSort)
    }

    var selectedRuleMatch: CleanupMatch? { cleanup?.first { $0.rule == selectedRule } }
    var selectedAppUsage: AppUsage? { apps?.apps.first { $0.id == selectedApp } }
    var selectedLeftoverGroup: LeftoverGroup? { apps?.leftovers.first { $0.id == selectedLeftover } }
}
