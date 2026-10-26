import Foundation
import DiskLensCore

/// Headless localization check: `DISKLENS_L10N_SELFTEST=1` prints a few localized strings in the
/// language the system picked for the app (try `-AppleLanguages '(en)'`), then exits.
@MainActor
enum L10nSelfTest {
    static func run() -> Never {
        let count = 1, many = 3
        print("Localization: \(Bundle.main.preferredLocalizations.first ?? "-") of \(Set(Bundle.main.localizations).sorted())")
        print("AI answer language: \(AILanguage.current)")
        print("Sidebar: \(SidebarItem.allCases.map(\.title).joined(separator: " | "))")
        print("Plural (1): \(String(localized: "要將 \(count) 個項目丟到垃圾桶嗎？"))")
        print("Plural (3): \(String(localized: "要將 \(many) 個項目丟到垃圾桶嗎？"))")
        print("Snapshots (3): \(String(localized: "本機快照 \(many) 個"))")
        print("Cleanup rule: \(CleanupRuleID.trash.title) — \(CleanupRuleID.trash.summary)")
        print("Safety: \(CleanupSafety.caution.title)")
        print("Category: \(FileCategory.diskImage.title)")
        print("Consent title: \(String(localized: "要用 \(AppleOnDeviceProvider.info.displayName) 說明這些項目嗎？"))")
        print("Protection: \(ProtectionReason.systemFile.message)")
        print("AI error: \(AIError.timedOut(seconds: 90).message)")
        exit(0)
    }
}
