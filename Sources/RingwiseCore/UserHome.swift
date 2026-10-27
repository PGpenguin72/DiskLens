import Foundation

/// The user's real home folder. Inside the App Sandbox `NSHomeDirectory()` points at the app's container
/// (`~/Library/Containers/<id>/Data`), but scan results and rules are about the real `/Users/<name>`.
public enum UserHome {
    public static let path: String = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }()
}
