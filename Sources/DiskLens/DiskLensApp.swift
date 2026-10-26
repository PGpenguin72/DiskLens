import SwiftUI

/// Entry point: runs the headless self-test when `DISKLENS_SELFTEST` is set, otherwise the app.
@main @MainActor
enum DiskLensMain {
    static func main() {
        if let folder = ProcessInfo.processInfo.environment["DISKLENS_SELFTEST"], !folder.isEmpty {
            SelfTest.run(folder: folder)
        }
        if let path = ProcessInfo.processInfo.environment["DISKLENS_AI_SELFTEST"], !path.isEmpty {
            AISelfTest.run(path: path)
        }
        if ProcessInfo.processInfo.environment["DISKLENS_L10N_SELFTEST"] != nil {
            L10nSelfTest.run()
        }
        OverlayScrollerStyle.install()
        DiskLensApp.main()
    }
}

struct DiskLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("DiskLens", id: "main") {
            ContentView()
                .environment(model)
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("掃描整個磁碟") { model.scanWholeDisk() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("選擇資料夾並掃描…") { model.chooseFolderAndScan() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .help) {
                Button("新手導覽") { model.showingOnboarding = true }
                Divider()
                Link("隱私權政策", destination: AppLinks.privacy)
                Link("使用條款", destination: AppLinks.terms)
                Link("在 GitHub 上查看原始碼", destination: AppLinks.repository)
                Link("回報問題", destination: AppLinks.issues)
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Also makes the raw binary (outside the .app bundle) behave like a regular app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Public pages for the Help menu and Settings.
enum AppLinks {
    static let repository = URL(string: "https://github.com/PGpenguin72/DiskLens")!
    static let issues = URL(string: "https://github.com/PGpenguin72/DiskLens/issues")!
    static let privacy = URL(string: "https://github.com/PGpenguin72/DiskLens/blob/main/docs/PRIVACY.md")!
    static let terms = URL(string: "https://github.com/PGpenguin72/DiskLens/blob/main/docs/TERMS.md")!
}
