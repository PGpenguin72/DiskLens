import Foundation

public enum Protection: Sendable, Equatable {
    case allowed
    /// Deleting is blocked; the reason says why.
    case blocked(ProtectionReason)
    /// Allowed, but the user must confirm the warning.
    case warn(ProtectionReason)
}

/// Why a path is protected. Core has no user-facing text: the app turns these into localized messages.
public enum ProtectionReason: Sendable, Equatable {
    /// A system or user root folder (/, ~/Documents, …) that must never be trashed as a whole.
    case essentialFolder
    /// Inside the sealed system (/System, /usr, /bin, /sbin).
    case systemFile
    /// System-level data (/Library, /private): may affect other apps or need admin rights.
    case systemLevel
    /// App data under ~/Library: the app may need to be set up or signed in again.
    case appData
}

/// Thrown by `FileActions.trash` / `move` for a blocked path.
public struct ProtectedItemError: Error, Equatable {
    public let reason: ProtectionReason
}

public enum FileActions {
    private static let home = UserHome.path

    /// Paths that must never be trashed (exact match or any ancestor of them).
    private static let blockedRoots: [String] = [
        "/", "/System", "/usr", "/bin", "/sbin", "/private", "/Library", "/Applications", "/Users",
        "/opt", "/cores", "/etc", "/var", "/tmp",
        home, home + "/Library", home + "/Documents", home + "/Desktop", home + "/Downloads",
    ]

    public static func protection(for path: String) -> Protection {
        let p = path.hasSuffix("/") && path.count > 1 ? String(path.dropLast()) : path
        if blockedRoots.contains(p) { return .blocked(.essentialFolder) }
        if p.hasPrefix("/System/") || p.hasPrefix("/usr/") || p.hasPrefix("/bin/") || p.hasPrefix("/sbin/") {
            return .blocked(.systemFile)
        }
        if p.hasPrefix("/private/") || p.hasPrefix("/Library/") {
            return .warn(.systemLevel)
        }
        if p.hasPrefix(home + "/Library/") {
            return .warn(.appData)
        }
        return .allowed
    }

    /// Moves the item to the Trash. Returns the URL inside the Trash.
    @discardableResult
    public static func trash(_ url: URL) throws -> URL? {
        if case .blocked(let why) = protection(for: url.path) {
            throw ProtectedItemError(reason: why)
        }
        var result: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &result)
        return result as URL?
    }

    /// Moves the item into `folder`, keeping its name.
    public static func move(_ url: URL, into folder: URL) throws -> URL {
        if case .blocked(let why) = protection(for: url.path) {
            throw ProtectedItemError(reason: why)
        }
        let dest = folder.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: dest)
        return dest
    }
}
