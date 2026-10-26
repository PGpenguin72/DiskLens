import SwiftUI

/// Explains why Full Disk Access is needed and links to System Settings.
struct FullDiskAccessBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("需要「完整磁碟取用權限」").font(.headline)
                Text("沒有這個權限時，郵件、訊息、Safari 和部分 App 的資料夾無法讀取，掃描結果會少算空間。請到「系統設定 › 隱私權與安全性 › 完整磁碟取用權限」開啟 DiskLens，然後重新掃描。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.unreadableCount > 0 {
                    Button("這次掃描有 \(model.unreadableCount) 個資料夾無法讀取，查看清單") {
                        model.showingUnreadable = true
                    }
                    .buttonStyle(.link)
                    .font(.callout)
                }
            }
            Spacer(minLength: 8)
            Button("開啟系統設定") { FullDiskAccess.openSettings() }
            Button("隱藏", systemImage: "xmark") { model.fullDiskAccessBannerDismissed = true }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("隱藏提示")
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
    }
}
