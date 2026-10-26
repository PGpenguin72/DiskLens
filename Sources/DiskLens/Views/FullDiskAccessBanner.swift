import SwiftUI

/// Explains why Full Disk Access is needed and links to System Settings.
struct FullDiskAccessBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("開啟「完整磁碟取用權限」才看得到全部").font(.headline)
                Text("沒有權限時，郵件、訊息、Safari 和部分 App 的資料夾讀不到，空間會少算。開啟後重新掃描即可。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if model.unreadableCount > 0 {
                    Button("這次有 \(model.unreadableCount) 個資料夾讀不到，查看清單") {
                        model.showingUnreadable = true
                    }
                    .buttonStyle(.link)
                    .font(.callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("開啟系統設定") { FullDiskAccess.openSettings() }
                .buttonStyle(.glassProminent)
                .tint(.orange)
            Button("隱藏", systemImage: "xmark") { model.fullDiskAccessBannerDismissed = true }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .help("隱藏提示")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 20, tint: .orange.opacity(0.12))
    }
}
