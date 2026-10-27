import AppKit

/// Version, author and support links shown in About, Settings and the Help menu.
enum AppInfo {
    static let author = "PGpenguin72"
    static let copyright = "© 2026 PGpenguin72"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Which distribution this binary is, so bug reports say where it came from.
    static var edition: String {
        #if APP_STORE
        "Mac App Store"
        #else
        Bundle.main.bundleURL.pathExtension == "app" ? "Direct download" : "Built from source"
        #endif
    }

    /// `edition` in the UI language (diagnostics keep the English one).
    static var localizedEdition: String {
        #if APP_STORE
        String(localized: "Mac App Store 版")
        #else
        Bundle.main.bundleURL.pathExtension == "app" ? String(localized: "直接下載版") : String(localized: "自行建置版")
        #endif
    }

    static var macOSVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// Hardware model identifier such as "Mac16,1".
    static var macModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Mac" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    static var architecture: String {
        #if arch(arm64)
        "Apple Silicon"
        #else
        "Intel"
        #endif
    }

    /// Plain-text diagnostics for bug reports. Deliberately contains no paths or scan results.
    static var diagnostics: String {
        """
        DiskLens \(version) (\(build)) · \(edition)
        \(macOSVersion) · \(macModel) · \(architecture)
        Language: \(Bundle.main.preferredLocalizations.first ?? "?")
        """
    }

    /// What the diagnostics contain, shown wherever they are sent or copied.
    static var diagnosticsDisclosure: String {
        String(localized: "只包含 App 版本、系統版本、機型與介面語言，不含任何檔案、路徑或掃描結果。你可以在送出前刪除這一段。")
    }

    /// Diagnostics with a clear label, for email, GitHub and the clipboard.
    static var labeledDiagnostics: String {
        String(localized: "—— 診斷資訊（由 DiskLens 自動附上）——") + "\n" + diagnosticsDisclosure + "\n\n" + diagnostics
    }

    static func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(labeledDiagnostics, forType: .string)
    }

    // MARK: Links

    static let repository = URL(string: "https://github.com/PGpenguin72/DiskLens")!
    static let releases = URL(string: "https://github.com/PGpenguin72/DiskLens/releases")!
    static let privacy = URL(string: "https://github.com/PGpenguin72/DiskLens/blob/main/docs/PRIVACY.md")!
    static let terms = URL(string: "https://github.com/PGpenguin72/DiskLens/blob/main/docs/TERMS.md")!
    static let license = URL(string: "https://github.com/PGpenguin72/DiskLens/blob/main/LICENSE")!
    /// Translation guide; switch to the Crowdin project page once it exists.
    static let translate = URL(string: "https://github.com/PGpenguin72/DiskLens/blob/main/docs/TRANSLATING.md")!

    /// GitHub bug-report form with the system details pre-filled (field ids from bug_report.yml).
    static var bugReport: URL {
        var c = URLComponents(string: "https://github.com/PGpenguin72/DiskLens/issues/new")!
        c.queryItems = [
            URLQueryItem(name: "template", value: "bug_report.yml"),
            URLQueryItem(name: "macos", value: "\(macOSVersion), \(macModel) (\(architecture))"),
            URLQueryItem(name: "what", value: "\n\n\n" + labeledDiagnostics),
        ]
        return c.url!
    }

    static let feedbackEmail = "developer@pg72.tw"

    /// Email to the developer with the labeled diagnostics at the bottom of the body.
    static var emailReport: URL {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = feedbackEmail
        c.queryItems = [
            URLQueryItem(name: "subject", value: String(localized: "DiskLens 問題回報") + " (\(version), \(build))"),
            URLQueryItem(name: "body", value: String(localized: "請描述你遇到的問題，或想給 DiskLens 的建議：") + "\n\n\n\n\n" + labeledDiagnostics),
        ]
        return c.url!
    }

    static var featureRequest: URL {
        URL(string: "https://github.com/PGpenguin72/DiskLens/issues/new?template=feature_request.yml")!
    }
}
