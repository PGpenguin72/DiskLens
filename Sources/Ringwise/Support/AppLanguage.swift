import AppKit

/// In-app language override. macOS reads the app's own `AppleLanguages` preference at launch, so a
/// change applies after a relaunch; `.system` removes the override and follows System Settings.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, zhHant = "zh-Hant", zhHans = "zh-Hans", en

    var id: Self { self }

    var nativeName: String {
        switch self {
        case .system: ""
        case .zhHant: "繁體中文"
        case .zhHans: "简体中文"
        case .en: "English"
        }
    }

    private static let key = "AppleLanguages"

    /// The override stored in the app's own preferences (not the global language list).
    static var current: AppLanguage {
        guard let id = Bundle.main.bundleIdentifier,
              let list = UserDefaults.standard.persistentDomain(forName: id)?[key] as? [String],
              let first = list.first else { return .system }
        return AppLanguage(rawValue: first) ?? .system
    }

    /// The choice in effect when the app launched, to tell whether a relaunch is pending.
    static let launched = current

    func apply() {
        if self == .system {
            UserDefaults.standard.removeObject(forKey: Self.key)
        } else {
            UserDefaults.standard.set([rawValue], forKey: Self.key)
        }
    }

    /// Whether this build can reopen itself (the sandboxed App Store build can't spawn the helper).
    static var canRelaunch: Bool {
        #if APP_STORE
        false
        #else
        Bundle.main.bundleURL.pathExtension == "app"
        #endif
    }

    /// Quits, and in the direct build reopens the app once this process has exited. A copy started
    /// while this one is still running would not get its main window.
    static func relaunch() {
        #if !APP_STORE
        if canRelaunch {
            let helper = Process()
            helper.executableURL = URL(fileURLWithPath: "/bin/sh")
            helper.arguments = ["-c", "while /bin/kill -0 \"$0\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$1\"",
                                String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath]
            try? helper.run()
        }
        #endif
        NSApp.terminate(nil)
    }
}
