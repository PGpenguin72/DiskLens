import SwiftUI

/// First-launch tour. Shown once (and from 說明 › 新手導覽) as a sheet over the main window.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let tint: Color
        let title: LocalizedStringKey
        let body: LocalizedStringKey
        let points: [LocalizedStringKey]
    }

    private var pages: [Page] {
        [
            Page(id: 0, symbol: "internaldrive.fill", tint: Theme.used,
                 title: "歡迎使用 DiskLens",
                 body: "幾十秒內掃完整顆磁碟，一眼看出空間都跑去哪了。",
                 points: ["只讀取檔案名稱、大小和日期，不會讀取檔案內容", "所有分析都在你的 Mac 上完成，不會上傳任何資料"]),
            Page(id: 1, symbol: "chart.pie.fill", tint: Theme.color(1),
                 title: "看懂環狀圖",
                 body: "中心是目前的資料夾，往外每一圈深入一層，弧越長代表越佔空間。",
                 points: ["滑鼠移上去會顯示名稱、大小和百分比", "點一下資料夾就會進入，點中心回到上一層", "表格、圖例和環狀圖的顏色互相對應"]),
            Page(id: 2, symbol: "checklist", tint: Theme.color(2),
                 title: "選取與安全刪除",
                 body: "選好項目後，底部會出現操作列，顯示可以釋放多少空間。",
                 points: ["開啟「多選」後，單擊就能加選或取消，不用按 ⌘", "刪除只會移到垃圾桶，清空前都能復原", "系統的重要檔案受保護，不能刪除"]),
            Page(id: 3, symbol: "sparkles.rectangle.stack.fill", tint: Theme.color(4),
                 title: "找出可以清的東西",
                 body: "左側欄有更多整理好的視角，幫你更快找到目標。",
                 points: ["App：每個 App 佔了多少，包含資料和快取，以及已移除 App 的殘留", "檔案類型：影片、照片、磁碟映像、開發快取⋯⋯", "可清理項目：依規則找出快取和舊檔案，並標示是否安全"]),
            Page(id: 4, symbol: "sparkles", tint: Theme.color(3),
                 title: "AI 小幫手（選用）",
                 body: "看不懂某個檔案是什麼？選取後按「問 AI」，請 AI 說明它是什麼、能不能刪。",
                 points: ["第一次使用前會先徵求你的同意，並說明會送出哪些資訊", "只送出路徑、名稱、大小、日期，絕不送出檔案內容", "AI 的回答只是建議，DiskLens 不會自動刪除任何東西"]),
            Page(id: 5, symbol: "lock.shield.fill", tint: .orange,
                 title: permissionTitle,
                 body: permissionBody,
                 points: permissionPoints),
        ]
    }

    #if APP_STORE
    private var permissionTitle: LocalizedStringKey { "授權讀取磁碟" }
    private var permissionBody: LocalizedStringKey { "macOS 會請你在第一次掃描時選擇要掃描的磁碟或資料夾，DiskLens 之後會記住這個授權。" }
    private var permissionPoints: [LocalizedStringKey] {
        ["掃描整個磁碟時，請在視窗左側選擇「Macintosh HD」", "授權隨時可以在「設定」裡移除"]
    }
    #else
    private var permissionTitle: LocalizedStringKey { "開啟完整磁碟取用權限" }
    private var permissionBody: LocalizedStringKey { "沒有這個權限，郵件、訊息、Safari 等資料夾讀不到，空間會少算。" }
    private var permissionPoints: [LocalizedStringKey] {
        ["系統設定 › 隱私權與安全性 › 完整磁碟取用權限 › 開啟 DiskLens", "開啟後重新掃描即可"]
    }
    #endif

    var body: some View {
        let current = pages[page]
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                Image(systemName: current.symbol)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(current.tint.gradient)
                    .frame(width: 104, height: 104)
                    .glassEffect(.regular.tint(current.tint.opacity(0.18)), in: .circle)
                    .id(current.id)
                    .transition(.scale.combined(with: .opacity))
                Text(current.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(current.body)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(current.points.enumerated()), id: \.offset) { _, point in
                        Label {
                            Text(point)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(current.tint)
                        }
                    }
                }
                .font(.callout)
                .padding(16)
                .frame(maxWidth: 460, alignment: .leading)
                .glassCard(cornerRadius: 18)
            }
            .padding(.top, 36)
            .padding(.horizontal, 40)
            .frame(maxHeight: .infinity, alignment: .top)

            HStack {
                Button("略過") { finish() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .opacity(page < pages.count - 1 ? 1 : 0)
                Spacer()
                HStack(spacing: 7) {
                    ForEach(pages) { p in
                        Capsule()
                            .fill(p.id == page ? AnyShapeStyle(current.tint) : AnyShapeStyle(.primary.opacity(0.2)))
                            .frame(width: p.id == page ? 20 : 7, height: 7)
                    }
                }
                Spacer()
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        if page > 0 {
                            Button("上一步") { withAnimation(.spring(duration: 0.35)) { page -= 1 } }
                                .buttonStyle(.glass)
                        }
                        if page < pages.count - 1 {
                            Button("下一步") { withAnimation(.spring(duration: 0.35)) { page += 1 } }
                                .buttonStyle(.glassProminent)
                                .keyboardShortcut(.defaultAction)
                        } else {
                            Button("開始使用") { finish() }
                                .buttonStyle(.glassProminent)
                                .keyboardShortcut(.defaultAction)
                        }
                    }
                }
                .controlSize(.large)
            }
            .padding(20)
        }
        .frame(width: 620, height: 560)
        .background(AmbientBackground())
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: OnboardingView.seenKey)
        dismiss()
    }

    static let seenKey = "hasSeenOnboarding"
}
