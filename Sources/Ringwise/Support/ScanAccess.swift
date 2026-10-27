import AppKit

/// Read access to scan roots under the App Sandbox.
///
/// In the Mac App Store build the app may only read what the user picked in an open panel. The pick is
/// remembered as a security-scoped bookmark, so the user grants the disk once. The direct-download
/// build is not sandboxed and every call is a pass-through.
@MainActor
enum ScanAccess {
    /// Returns the URL to scan for `root`, asking the user to grant it if needed; `nil` if they cancel.
    static func prepare(_ root: URL) -> URL? {
        #if APP_STORE
        // Headless self-test: no panel can be answered, so scan with whatever the sandbox allows.
        if ProcessInfo.processInfo.environment["RINGWISE_SELFTEST"] != nil { return root }
        if let granted = resolveBookmark(covering: root) { return granted }
        guard let picked = askForAccess(suggesting: root) else { return nil }
        remember(picked)
        return picked
        #else
        return root
        #endif
    }

    /// Stores access to a folder the user just picked in an open panel.
    static func remember(_ url: URL) {
        #if APP_STORE
        guard let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil,
                                               relativeTo: nil) else { return }
        var all = bookmarks
        all[url.standardizedFileURL.path] = data
        bookmarks = all
        _ = url.startAccessingSecurityScopedResource()
        #endif
    }

    /// Forgets every granted location (Settings › General).
    static func forgetAll() {
        #if APP_STORE
        bookmarks = [:]
        #endif
    }

    #if APP_STORE
    private static let defaultsKey = "scanAccessBookmarks"

    private static var bookmarks: [String: Data] {
        get { UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    /// A stored bookmark whose folder contains `root`, with access started (kept for the app's lifetime).
    private static func resolveBookmark(covering root: URL) -> URL? {
        let target = root.standardizedFileURL.path
        for (path, data) in bookmarks where target == path || target.hasPrefix(path == "/" ? "/" : path + "/") {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                     relativeTo: nil, bookmarkDataIsStale: &stale),
                  url.startAccessingSecurityScopedResource() else { continue }
            if stale { remember(url) }
            return root
        }
        return nil
    }

    private static func askForAccess(suggesting root: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = root
        panel.prompt = String(localized: "允許掃描")
        panel.message = root.path == "/"
            ? String(localized: "macOS 需要你授權一次：請在左側選擇「Macintosh HD」（或你的磁碟），然後按「允許掃描」。Ringwise 只讀取檔案名稱與大小，不會讀取檔案內容。")
            : String(localized: "請選擇要讓 Ringwise 掃描的資料夾。Ringwise 只讀取檔案名稱與大小，不會讀取檔案內容。")
        return panel.runModal() == .OK ? panel.url : nil
    }
    #endif
}
