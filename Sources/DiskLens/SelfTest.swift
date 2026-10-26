import AppKit
import SwiftUI
import DiskLensCore

/// Headless end-to-end check of the scan → model → rows pipeline.
///
/// `DISKLENS_SELFTEST=<folder>` scans the folder through `AppModel`, prints the top 10 children
/// and the 5 largest files, then exits. With `DISKLENS_SELFTEST_TRASH=1` and a folder inside a
/// temporary directory, it also moves the largest file to the Trash through the model.
/// `DISKLENS_SNAPSHOT=<file.png>` renders the main window offscreen after the scan.
@MainActor
enum SelfTest {
    static func run(folder: String) -> Never {
        let url = URL(fileURLWithPath: (folder as NSString).expandingTildeInPath).standardizedFileURL
        let model = AppModel()
        print("DiskLens self-test: scanning \(url.path)")
        model.startScan(url)
        spin { model.isScanning }

        guard model.scanState == .finished, let tree = model.tree else {
            print("Scan did not finish: \(model.scanState)")
            exit(1)
        }
        spin { model.isLoadingLargeFiles }

        print(String(format: "Scanned %d nodes in %.2f s, total %@, unreadable folders: %d",
                     model.nodeCount, model.scanDuration ?? 0, ByteFormat.string(tree.size(tree.root)),
                     model.unreadableCount))
        print("\nTop 10 children:")
        for row in model.folderRows.prefix(10) {
            print("  \(pad(ByteFormat.string(row.size)))  \(row.isDirectory ? "[D]" : "   ") \(row.name)  (\(row.fileCount) files)")
        }
        print("\nLargest 5 files:")
        for row in model.largeRows.prefix(5) {
            print("  \(pad(ByteFormat.string(row.size)))  \(row.path)")
        }

        let searchStart = Date()
        model.searchText = String(model.largeRows.first?.name.prefix(4) ?? "")
        spin { model.isSearching }
        print(String(format: "\nSearch \"%@\": %d hits in %.2f s (incl. debounce)", model.searchText,
                     model.searchRows.count, Date().timeIntervalSince(searchStart)))

        model.searchText = ""
        spin { model.isSearching }
        if let png = ProcessInfo.processInfo.environment["DISKLENS_SNAPSHOT"] {
            snapshot(model: model, to: URL(fileURLWithPath: png))
        }
        benchmarkBusiestFolder(model: model, tree: tree)

        if ProcessInfo.processInfo.environment["DISKLENS_SELFTEST_TRASH"] == "1" {
            trashLargest(model: model, root: url)
        }
        exit(0)
    }

    /// Renders `ContentView` in an offscreen window and writes a PNG.
    private static func snapshot(model: AppModel, to url: URL) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: 1180, height: 760),
                              styleMask: [.titled, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: ContentView().environment(model))
        window.orderFrontRegardless()
        let deadline = Date(timeIntervalSinceNow: 1.5)
        spin { Date() < deadline }
        guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        print("\nSnapshot written to \(url.path)")
        window.orderOut(nil)
    }

    /// Times opening and name-sorting the folder with the most direct children.
    private static func benchmarkBusiestFolder(model: AppModel, tree: FileTree) {
        var busiest = tree.root, most = 0
        var stack = [tree.root]
        while let id = stack.popLast() {
            let kids = tree.children(id)
            if kids.count > most { most = kids.count; busiest = id }
            stack.append(contentsOf: kids.filter { tree.isDirectory($0) })
        }
        let t0 = Date()
        model.open(busiest)
        let opened = Date().timeIntervalSince(t0)
        let t1 = Date()
        model.folderSort = [KeyPathComparator(\FileRow.name)]
        spin { model.isSortingFolder }
        let sorted = Date().timeIntervalSince(t1)
        print(String(format: "\nBusiest folder %@: %d rows, opened in %.0f ms (main thread), name-sorted in %.0f ms",
                     tree.path(busiest), model.folderRows.count, opened * 1000, sorted * 1000))
        model.folderSort = FileRow.defaultSort
        spin { model.isSortingFolder }
    }

    private static func trashLargest(model: AppModel, root: URL) {
        let temp = [NSTemporaryDirectory(), "/tmp/", "/private/tmp/", "/private/var/folders/"]
        guard temp.contains(where: { root.path.hasPrefix($0) || (root.path + "/").hasPrefix($0) }),
              let tree = model.tree, let victim = model.largeRows.first else {
            print("\nTrash test skipped (folder must be inside a temporary directory).")
            return
        }
        let before = tree.size(tree.root)
        model.requestTrash([victim.id])
        guard let request = model.pendingTrash else {
            print("\nTrash request refused: \(model.errorMessage ?? "?")")
            return
        }
        print("\nTrash confirm: \(request.title) \(request.message)")
        model.confirmTrash(request)
        spin { model.isPerformingAction }
        spin { model.isLoadingLargeFiles }
        let exists = FileManager.default.fileExists(atPath: victim.path)
        print("Trashed \(victim.name): root \(ByteFormat.string(before)) -> \(ByteFormat.string(tree.size(tree.root))), still on disk: \(exists), error: \(model.errorMessage ?? "none")")
    }

    /// Runs the main run loop (which drives main-actor tasks) while `condition` holds.
    private static func spin(_ condition: () -> Bool) {
        while condition() {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
    }

    private static func pad(_ s: String) -> String {
        String(repeating: " ", count: max(0, 10 - s.count)) + s
    }
}
