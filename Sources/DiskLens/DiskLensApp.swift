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
        .commands { AppCommands(model: model) }

        Window("關於 DiskLens", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)

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

/// Menu bar commands: scanning, the custom About window and the Help menu.
struct AppCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("關於 DiskLens") { openWindow(id: "about") }
        }
        CommandGroup(replacing: .newItem) {
            Button("掃描整個磁碟") { model.scanWholeDisk() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("選擇資料夾並掃描…") { model.chooseFolderAndScan() }
                .keyboardShortcut("o")
        }
        CommandGroup(replacing: .help) {
            Button("新手導覽") { model.showingOnboarding = true }
            Divider()
            Link("回報問題…", destination: AppInfo.bugReport)
            Link("用 Email 回報…", destination: AppInfo.emailReport)
            Link("建議新功能…", destination: AppInfo.featureRequest)
            Button("拷貝診斷資訊") { AppInfo.copyDiagnostics() }
            Divider()
            Link("協助翻譯 DiskLens", destination: AppInfo.translate)
            Link("在 GitHub 上查看原始碼", destination: AppInfo.repository)
            #if !APP_STORE
            Link("檢查新版本", destination: AppInfo.releases)
            #endif
            Divider()
            Link("隱私權政策", destination: AppInfo.privacy)
            Link("使用條款", destination: AppInfo.terms)
        }
    }
}
