import Foundation

public enum Protection: Sendable, Equatable {
    case allowed
    /// Deleting is blocked; the string explains why.
    case blocked(String)
    /// Allowed, but the user must confirm the warning.
    case warn(String)
}

public enum FileActions {
    private static let home = NSHomeDirectory()

    /// Paths that must never be trashed (exact match or any ancestor of them).
    private static let blockedRoots: [String] = [
        "/", "/System", "/usr", "/bin", "/sbin", "/private", "/Library", "/Applications", "/Users",
        "/opt", "/cores", "/etc", "/var", "/tmp",
        home, home + "/Library", home + "/Documents", home + "/Desktop", home + "/Downloads",
    ]

    public static func protection(for path: String) -> Protection {
        let p = path.hasSuffix("/") && path.count > 1 ? String(path.dropLast()) : path
        if blockedRoots.contains(p) { return .blocked("這是系統或使用者的重要資料夾，不能整個刪除。") }
        if p.hasPrefix("/System/") || p.hasPrefix("/usr/") || p.hasPrefix("/bin/") || p.hasPrefix("/sbin/") {
            return .blocked("macOS 系統檔案受保護，無法刪除。")
        }
        if p.hasPrefix("/private/") || p.hasPrefix("/Library/") {
            return .warn("這是系統層級的檔案，刪除可能影響其他 App 或需要管理員權限。")
        }
        if p.hasPrefix(home + "/Library/") {
            return .warn("這是 App 的資料。刪除後該 App 可能需要重新設定或登入。")
        }
        return .allowed
    }

    /// Moves the item to the Trash. Returns the URL inside the Trash.
    @discardableResult
    public static func trash(_ url: URL) throws -> URL? {
        if case .blocked(let why) = protection(for: url.path) {
            throw NSError(domain: "DiskLens", code: 1, userInfo: [NSLocalizedDescriptionKey: why])
        }
        var result: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &result)
        return result as URL?
    }

    /// Moves the item into `folder`, keeping its name.
    public static func move(_ url: URL, into folder: URL) throws -> URL {
        if case .blocked(let why) = protection(for: url.path) {
            throw NSError(domain: "DiskLens", code: 1, userInfo: [NSLocalizedDescriptionKey: why])
        }
        let dest = folder.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: dest)
        return dest
    }
}
