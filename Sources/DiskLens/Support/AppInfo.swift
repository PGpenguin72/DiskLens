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

    static func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
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
            URLQueryItem(name: "what", value: "\n\n---\n\(diagnostics)"),
        ]
        return c.url!
    }

    static var featureRequest: URL {
        URL(string: "https://github.com/PGpenguin72/DiskLens/issues/new?template=feature_request.yml")!
    }
}
