import AppKit
import Darwin

/// Detects whether the app has Full Disk Access (TCC "App Management / All Files").
enum FullDiskAccess {
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!

    /// Probes TCC-protected locations. Returns `true` when access is granted or cannot be determined.
    static func isGranted() -> Bool {
        if ProcessInfo.processInfo.environment["DISKLENS_FAKE_NO_FDA"] != nil { return false }
        let home = NSHomeDirectory()

        // The system TCC database exists on every Mac and is only readable with Full Disk Access.
        let fd = open("/Library/Application Support/com.apple.TCC/TCC.db", O_RDONLY)
        if fd >= 0 {
            close(fd)
            return true
        }
        if errno == EPERM || errno == EACCES { return false }

        for dir in [home + "/Library/Safari", home + "/Library/Mail"] {
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: dir)
                return true
            } catch let error as CocoaError where error.code == .fileReadNoPermission {
                return false
            } catch {
                continue
            }
        }
        return true
    }

    static func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }
}
