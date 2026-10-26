import SwiftUI
import AppKit
import Observation
import os
import DiskLensCore

/// Central UI state.
///
/// The `FileTree` itself is not observed: views read precomputed row arrays instead, and
/// `revision` is bumped whenever the tree is mutated so derived state can refresh.
@MainActor @Observable
final class AppModel {
    // MARK: Tree

    @ObservationIgnored private(set) var tree: FileTree?
    /// Observed mirror of `tree != nil`.
    private(set) var hasTree = false
    /// Incremented after every mutation of `tree`.
    private(set) var revision = 0

    // MARK: Scan

    private(set) var scanState: ScanState = .idle
    private(set) var progress = ScanProgress(itemsScanned: 0, bytesScanned: 0, currentPath: "")
    private(set) var scanElapsed: TimeInterval = 0
    private(set) var scanRoot: URL?
    private(set) var scanDuration: TimeInterval?
    @ObservationIgnored private var scanTask: Task<Void, Never>?

    var isScanning: Bool { scanState == .scanning }

    // MARK: Environment

    private(set) var volume: VolumeInfo?
    private(set) var snapshotCount: Int?
    private(set) var hasFullDiskAccess = true
    var fullDiskAccessBannerDismissed = false

    // MARK: Navigation & selection

    var sidebar: SidebarItem = .folders {
        didSet { if sidebar != oldValue { selection = [] } }
    }
    private(set) var currentDir: NodeID?
    private var backStack: [NodeID] = []
    private var forwardStack: [NodeID] = []
    var selection: Set<NodeID> = []
    /// When on, a plain click adds or removes a row instead of replacing the selection (no ⌘ needed).
    var multiSelectMode = false

    /// Selection binding for tables; applies multi-select mode on top of the table's own behaviour.
    var tableSelection: Binding<Set<NodeID>> {
        Binding(get: { self.selection }, set: { self.applyTableSelection($0) })
    }

    /// Row the table toggled last, and when — a click on a row's check circle reaches both the table
    /// (on mouse-down) and the circle (on mouse-up); the circle must not undo the table's toggle.
    @ObservationIgnored private var lastTableToggle: (id: NodeID, at: Date)?

    private func applyTableSelection(_ new: Set<NodeID>) {
        guard multiSelectMode else { selection = new; return }
        // A plain click reports just the clicked row: toggle it. Shift/⌘/drag/⌘A report several: take them.
        if new.count == 1, let id = new.first {
            toggleSelection(id)
            lastTableToggle = (id, Date())
        } else if !new.isEmpty {
            selection = new
        }
    }

    /// Click on a row's check circle. Skipped when the same click already toggled the row via the table.
    func checkCircleTapped(_ id: NodeID) {
        if let last = lastTableToggle, last.id == id, Date().timeIntervalSince(last.at) < 0.6 { return }
        toggleSelection(id)
    }

    func toggleSelection(_ id: NodeID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var canGoUp: Bool {
        guard let tree, let currentDir else { return false }
        return tree.parent(currentDir) != nil
    }

    // MARK: Folder browser

    var folderSort = FileRow.defaultSort {
        didSet { sortFolderRows() }
    }
    private(set) var folderRows: [FileRow] = []
    /// Palette index of the biggest children of the current folder (sunburst, legend and table dots).
    private(set) var chartColorIndex: [NodeID: Int] = [:]
    /// Node under the pointer in the chart, legend or table; the sunburst highlights it.
    var highlighted: NodeID?
    /// True while a huge folder is being sorted in the background.
    private(set) var isSortingFolder = false
    @ObservationIgnored private var folderSortTask: Task<Void, Never>?

    // MARK: Large files

    var largeFilesMinimum: MinimumSize = .all {
        didSet { if largeFilesMinimum != oldValue { refreshLargeFiles() } }
    }
    var largeSort = FileRow.defaultSort {
        didSet { largeRows = largeRows.sorted(by: largeSort) }
    }
    private(set) var largeRows: [FileRow] = []
    private(set) var isLoadingLargeFiles = false
    @ObservationIgnored private var largeTask: Task<Void, Never>?

    // MARK: Search

    var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            if searchText.isEmpty != oldValue.isEmpty { selection = [] }
            runSearch(debounce: true)
        }
    }
    var searchSort = FileRow.defaultSort {
        didSet { searchRows = searchRows.sorted(by: searchSort) }
    }
    private(set) var searchRows: [FileRow] = []
    private(set) var isSearching = false
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    var isShowingSearch: Bool { hasTree && !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    // MARK: Actions & alerts

    var pendingTrash: TrashRequest?
    var errorMessage: String?
    var showingUnreadable = false
    var isPerformingAction = false

    init() {
        refreshEnvironment()
    }

    // MARK: - Environment

    /// Refreshes volume capacity and Full Disk Access state. Cheap; call on activation.
    func refreshEnvironment() {
        volume = VolumeInfo.current()
        hasFullDiskAccess = FullDiskAccess.isGranted()
    }

    /// Counts local APFS snapshots (spawns `tmutil`, so it runs off the main thread).
    func loadSnapshots() {
        Task {
            let count = await Task.detached(priority: .utility) { LocalSnapshots.list().count }.value
            snapshotCount = count
        }
    }

    // MARK: - Scanning

    func scanWholeDisk() {
        startScan(URL(fileURLWithPath: "/"))
    }

    func chooseFolderAndScan() {
        guard !isScanning else { return }
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if let url = Panels.chooseFolder(message: "選擇要掃描的資料夾", prompt: "掃描", startingAt: home) {
            startScan(url)
        }
    }

    func rescan() {
        if let scanRoot { startScan(scanRoot) }
    }

    func startScan(_ root: URL) {
        guard !isScanning else { return }
        resetTree()
        scanRoot = root
        scanState = .scanning
        scanElapsed = 0
        progress = ScanProgress(itemsScanned: 0, bytesScanned: 0, currentPath: root.path)

        // The scanner reports from background threads; keep only the latest value
        // and let a main-actor loop pick it up a few times per second.
        let latest = OSAllocatedUnfairLock<ScanProgress?>(initialState: nil)
        let started = Date()

        scanTask = Task {
            let poller = Task {
                while !Task.isCancelled {
                    if let p = latest.withLock({ value -> ScanProgress? in defer { value = nil }; return value }) {
                        progress = p
                    }
                    scanElapsed = Date().timeIntervalSince(started)
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            defer { poller.cancel() }

            let work = Task.detached(priority: .userInitiated) {
                try await Scanner().scan(root: root, options: ScanOptions()) { p in
                    latest.withLock { $0 = p }
                }
            }
            do {
                let tree = try await withTaskCancellationHandler {
                    try await work.value
                } onCancel: {
                    work.cancel()
                }
                finishScan(tree, duration: Date().timeIntervalSince(started))
            } catch is CancellationError {
                scanState = .idle
            } catch {
                scanState = .failed(error.localizedDescription)
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    private func resetTree() {
        folderSortTask?.cancel()
        largeTask?.cancel()
        searchTask?.cancel()
        tree = nil
        hasTree = false
        currentDir = nil
        backStack = []
        forwardStack = []
        selection = []
        folderRows = []
        largeRows = []
        searchRows = []
        scanDuration = nil
    }

    private func finishScan(_ tree: FileTree, duration: TimeInterval) {
        self.tree = tree
        hasTree = true
        revision += 1
        scanDuration = duration
        scanElapsed = duration
        scanState = .finished
        currentDir = tree.root
        rebuildFolderRows()
        refreshLargeFiles()
        runSearch(debounce: false)
        refreshEnvironment()
        loadSnapshots()
    }

    // MARK: - Navigation

    /// Opens a folder in the browser, recording history.
    func open(_ id: NodeID) {
        guard let tree, tree.isDirectory(id), id != currentDir else { return }
        if let currentDir { backStack.append(currentDir) }
        forwardStack.removeAll()
        setCurrentDir(id)
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        if let currentDir { forwardStack.append(currentDir) }
        setCurrentDir(previous)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        if let currentDir { backStack.append(currentDir) }
        setCurrentDir(next)
    }

    func goUp() {
        guard let tree, let currentDir, let parent = tree.parent(currentDir) else { return }
        open(parent)
        selection = [currentDir]
    }

    /// Shows a node in the folder browser: folders are opened, files are selected in their folder.
    func showInBrowser(_ id: NodeID) {
        guard let tree else { return }
        searchText = ""
        sidebar = .folders
        if tree.isDirectory(id) {
            open(id)
        } else if let parent = tree.parent(id) {
            open(parent)
            selection = [id]
        }
    }

    /// Double-click / Return in a table.
    func primaryAction(_ ids: Set<NodeID>) {
        guard let tree, ids.count == 1, let id = ids.first else { return }
        if sidebar == .folders && !isShowingSearch {
            if tree.isDirectory(id) { open(id) } else { reveal([id]) }
        } else {
            showInBrowser(id)
        }
    }

    /// Lineage of the current folder, for the breadcrumb.
    var breadcrumb: [NodeID] {
        guard let tree, let currentDir else { return [] }
        return tree.lineage(currentDir)
    }

    private func setCurrentDir(_ id: NodeID) {
        currentDir = id
        selection = []
        rebuildFolderRows()
    }

    // MARK: - Derived rows

    func rebuildFolderRows() {
        folderSortTask?.cancel()
        highlighted = nil
        guard let tree, let currentDir else {
            folderRows = []
            chartColorIndex = [:]
            isSortingFolder = false
            return
        }
        // Same cut-off as the sunburst, so only items actually drawn get a color.
        let minSize = Double(tree.size(currentDir)) * SunburstLayout.minFraction
        let drawn = tree.children(currentDir).prefix(Theme.palette.count).prefix { Double(tree.size($0)) >= minSize && tree.size($0) > 0 }
        chartColorIndex = Dictionary(uniqueKeysWithValues: drawn.enumerated().map { ($1, $0) })
        folderRows = FileRow.children(of: currentDir, in: tree)
        sortFolderRows()
    }

    /// Sorts the current folder. Huge folders are sorted off the main thread.
    private func sortFolderRows() {
        folderSortTask?.cancel()
        let rows = folderRows
        let order = folderSort
        guard rows.count > 5_000 else {
            folderRows = rows.sorted(by: order)
            isSortingFolder = false
            return
        }
        isSortingFolder = true
        let dir = currentDir
        folderSortTask = Task {
            let sorted = await Task.detached(priority: .userInitiated) { rows.sorted(by: order) }.value
            guard !Task.isCancelled, dir == currentDir else { return }
            folderRows = sorted
            isSortingFolder = false
        }
    }

    func refreshLargeFiles() {
        largeTask?.cancel()
        guard let tree else {
            largeRows = []
            return
        }
        isLoadingLargeFiles = true
        let minimum = largeFilesMinimum.rawValue
        let order = largeSort
        largeTask = Task {
            let rows = await Task.detached(priority: .userInitiated) {
                FileRow.list(tree.largestFiles(limit: 500, minSize: minimum), in: tree).sorted(by: order)
            }.value
            guard !Task.isCancelled else { return }
            largeRows = rows
            isLoadingLargeFiles = false
        }
    }

    private func runSearch(debounce: Bool) {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard let tree, !query.isEmpty else {
            searchRows = []
            isSearching = false
            return
        }
        isSearching = true
        let order = searchSort
        searchTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
            }
            let rows = await Task.detached(priority: .userInitiated) {
                FileRow.list(tree.search(query, limit: 1000), in: tree).sorted(by: order)
            }.value
            guard !Task.isCancelled else { return }
            searchRows = rows
            isSearching = false
        }
    }

    // MARK: - Mutation

    /// Applies removals (after trash / move) to the tree and refreshes all derived state.
    func applyRemoval(_ ids: [NodeID]) {
        guard let tree, !ids.isEmpty else { return }
        for id in ids { tree.remove(id) }
        revision += 1
        selection = selection.filter { tree.isLive($0) }
        backStack = backStack.filter { tree.isLive($0) }
        forwardStack = forwardStack.filter { tree.isLive($0) }
        if let currentDir, !tree.isLive(currentDir) {
            self.currentDir = tree.nearestLiveAncestor(of: currentDir)
        }
        rebuildFolderRows()
        refreshLargeFiles()
        runSearch(debounce: false)
        refreshEnvironment()
    }

    // MARK: - Status

    /// Count and total size of the current selection.
    var selectionSummary: (count: Int, size: Int64) {
        _ = revision
        guard let tree else { return (0, 0) }
        let targets = selection.count > 20_000 ? Array(selection) : tree.topLevelTargets(selection)
        return (selection.count, targets.reduce(0) { $0 + tree.size($1) })
    }

    var unreadableCount: Int {
        _ = revision
        return tree?.unreadable.count ?? 0
    }

    var nodeCount: Int {
        _ = revision
        return tree?.nodeCount ?? 0
    }

    var scanRootDisplayName: String {
        guard let scanRoot else { return "" }
        return scanRoot.path == "/" ? (volume?.name ?? "/") : scanRoot.lastPathComponent
    }
}
