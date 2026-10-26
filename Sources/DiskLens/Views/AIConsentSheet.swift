import SwiftUI
import DiskLensCore

/// Explicit consent before a provider is used for the first time: what runs, what is sent, who
/// processes it, and how to turn it off. Shows the exact prompt for the current request.
struct AIConsentSheet: View {
    let request: AIConsentRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var showsPrompt = false

    private var info: AIProviderInfo { request.provider.info }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    VStack(alignment: .leading, spacing: 14) {
                        if info.isOnDevice { onDeviceRows } else { cliRows }
                        ConsentRow(symbol: "doc.text.magnifyingglass", tint: .blue, title: "會用到哪些資料") {
                            Text("只有檔案與資料夾的路徑、名稱、大小、修改日期、項目數量，以及 DiskLens 自己的分類。**絕對不會讀取或傳送檔案內容。**")
                        }
                        ConsentRow(symbol: "exclamationmark.bubble", tint: .orange, title: "回答僅供參考") {
                            Text("AI 的回答只是建議，可能有錯。DiskLens 絕不會自動刪除任何東西，要不要刪除永遠由你決定。")
                        }
                        ConsentRow(symbol: "gearshape", tint: .secondary, title: "隨時可以關閉") {
                            Text("之後可以在「設定」（⌘,）的 AI 區段關閉 AI 說明、換用其他工具，或撤回這次同意。")
                        }
                    }
                    .padding(16)
                    .glassCard(cornerRadius: 18)

                    DisclosureGroup(isExpanded: $showsPrompt) {
                        ScrollView {
                            Text(request.prompt.text)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .frame(height: 200)
                        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
                        .padding(.top, 6)
                    } label: {
                        Text("預覽這次要使用的完整內容（\(request.prompt.items.count) 個項目）")
                            .font(.callout.weight(.medium))
                    }
                    if request.totalSelected > request.prompt.items.count {
                        Label("共選取 \(request.totalSelected) 個項目，這次只說明最大的 \(request.prompt.items.count) 個。",
                              systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
            }
            Divider()
            HStack {
                Spacer()
                Button("不要使用 AI", action: onDecline)
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                Button("同意並使用 \(info.displayName)", action: onAccept)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(16)
        }
        .frame(width: 560, height: 640)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.accentGradient)
                .frame(width: 52, height: 52)
                .glassEffect(.regular, in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text("要用 \(info.displayName) 說明這些項目嗎？")
                    .font(.title2.weight(.semibold))
                Text("第一次使用或更換 AI 工具時，DiskLens 都會先徵求你的同意。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var cliRows: some View {
        ConsentRow(symbol: "terminal", tint: .purple, title: "會啟動的工具") {
            VStack(alignment: .leading, spacing: 4) {
                Text("DiskLens 會在這台 Mac 上啟動你自己安裝的「\(info.displayName)」（\(info.vendor)）。")
                if let location = request.provider.location {
                    Text(location)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        ConsentRow(symbol: "person.crop.circle.badge.checkmark", tint: .green, title: "使用你自己的帳號") {
            Text("它會使用你在 \(info.vendor) 的帳號與訂閱方案，每次詢問都可能消耗你的用量或額度。")
        }
        ConsentRow(symbol: "hand.raised", tint: .pink, title: "隱私") {
            VStack(alignment: .leading, spacing: 4) {
                Text("這些資料會傳給 \(info.vendor) 處理，並適用 \(info.vendor) 的隱私權政策。DiskLens 本身不會把任何資料傳到網路上。")
                Link("查看 \(info.vendor) 的隱私權政策", destination: info.privacyURL)
                    .font(.callout)
            }
        }
    }

    @ViewBuilder private var onDeviceRows: some View {
        ConsentRow(symbol: "apple.intelligence", tint: .purple, title: "在這台 Mac 上處理") {
            Text("由 Apple 內建在這台 Mac 上的模型處理。不會透過網路傳送任何資料，也不會消耗任何付費額度。")
        }
        ConsentRow(symbol: "hand.raised", tint: .pink, title: "隱私") {
            VStack(alignment: .leading, spacing: 4) {
                Text("資料不會離開這台 Mac，DiskLens 本身也不會把任何資料傳到網路上。")
                Link("查看 Apple Intelligence 的隱私說明", destination: info.privacyURL)
                    .font(.callout)
            }
        }
    }
}

/// One labelled paragraph of the consent sheet.
private struct ConsentRow<Content: View>: View {
    let symbol: String
    let tint: Color
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                content
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Shown when no provider is available: what is supported and where to get it.
struct AINoProviderSheet: View {
    let reasons: [String: String]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("找不到可用的 AI 工具", systemImage: "sparkles")
                .font(.title2.weight(.semibold))
            Text("DiskLens 不會自己連上任何 AI 服務，而是使用你 Mac 上已有的 AI。請先開啟或安裝下列其中一項：")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(AIProviderRegistry.supported) { info in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.displayName).font(.headline)
                            if let reason = reasons[info.id] {
                                Text(reason).font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text(info.vendor).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Link(info.isOnDevice ? "了解如何開啟" : "安裝說明", destination: info.installURL)
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
            #if !APP_STORE
            Text("安裝 AI 命令列工具後，請先在「終端機」執行一次並登入，再回到 DiskLens。")
                .font(.caption)
                .foregroundStyle(.secondary)
            #endif
            HStack {
                Spacer()
                Button("好", action: onClose)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
