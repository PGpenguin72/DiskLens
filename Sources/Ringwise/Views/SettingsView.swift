import SwiftUI
import RingwiseCore

/// Settings window (⌘,): General, AI, Feedback and About.
struct SettingsView: View {
    enum Pane: Hashable { case general, ai, feedback, about }
    @State var pane: Pane = SettingsView.initialPane

    /// `.general`, unless a screenshot hook asked for another tab.
    private static var initialPane: Pane {
        switch ProcessInfo.processInfo.environment["RINGWISE_SETTINGS_PANE"] {
        case "ai": return .ai
        case "feedback": return .feedback
        case "about": return .about
        default: return .general
        }
    }

    var body: some View {
        TabView(selection: $pane) {
            Tab("一般", systemImage: "gearshape", value: .general) {
                GeneralSettings()
            }
            Tab("AI", systemImage: "sparkles", value: .ai) {
                AISettings()
            }
            Tab("意見回饋", systemImage: "bubble.left.and.text.bubble.right", value: .feedback) {
                FeedbackSettings()
            }
            Tab("關於", systemImage: "info.circle", value: .about) {
                AboutSettings()
            }
        }
        .frame(width: 560, height: 520)
    }
}

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @State private var language = AppLanguage.current
    @State private var accessCleared = false

    var body: some View {
        Form {
            Section {
                Picker("語言", selection: $language) {
                    ForEach(AppLanguage.allCases) { option in
                        // Language names are shown in their own language, so they're not localized.
                        if option == .system { Text("跟隨系統").tag(option) } else { Text(verbatim: option.nativeName).tag(option) }
                    }
                }
                .onChange(of: language) { _, new in new.apply() }
                if language != AppLanguage.launched {
                    HStack {
                        Text(AppLanguage.canRelaunch ? "更改語言後需要重新啟動 Ringwise。" : "結束 Ringwise 再重新打開後，就會換成新的語言。")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(AppLanguage.canRelaunch ? "立即重新啟動" : "結束 Ringwise") { AppLanguage.relaunch() }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            Section {
                LabeledContent("新手導覽") {
                    Button("再看一次") { model.showingOnboarding = true }
                }
            }
            #if APP_STORE
            Section {
                LabeledContent("已授權的磁碟與資料夾") {
                    Button(accessCleared ? "已移除" : "移除所有授權") {
                        ScanAccess.forgetAll()
                        accessCleared = true
                    }
                    .disabled(accessCleared)
                }
                Text("移除後，下次掃描時會再詢問一次。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .formStyle(.grouped)
    }
}

private struct FeedbackSettings: View {
    @State private var copied = false

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Link("回報問題…", destination: AppInfo.bugReport)
                } label: {
                    Text("遇到問題或當機")
                    Text("會打開 GitHub 的回報表單，並附上標示清楚的診斷資訊（版本與系統資訊，不含任何檔案資訊）。")
                }
                LabeledContent {
                    Link("寄 Email…", destination: AppInfo.emailReport)
                } label: {
                    Text("用 Email 回報")
                    Text("沒有 GitHub 帳號也可以寄信到 \(AppInfo.feedbackEmail)，信件底部會附上診斷資訊。")
                }
                LabeledContent {
                    Link("建議新功能…", destination: AppInfo.featureRequest)
                } label: {
                    Text("有想要的功能")
                    Text("歡迎到 GitHub 分享你的想法。")
                }
                LabeledContent {
                    Button(copied ? "已拷貝" : "拷貝") {
                        AppInfo.copyDiagnostics()
                        copied = true
                    }
                } label: {
                    Text("診斷資訊")
                    Text(verbatim: AppInfo.diagnosticsDisclosure)
                    Text(verbatim: AppInfo.diagnostics)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            } header: {
                Text("回報與建議")
            }
            Section {
                LabeledContent {
                    Link("協助翻譯…", destination: AppInfo.translate)
                } label: {
                    Text("讓 Ringwise 支援你的語言")
                    Text("目前支援繁體中文、简体中文和 English。翻譯可以由人工或 AI 協助完成。")
                }
            } header: {
                Text("翻譯")
            }
            Section {
                LabeledContent {
                    Link("前往 GitHub", destination: AppInfo.repository)
                } label: {
                    Text("在 GitHub 上給顆星")
                    Text("Ringwise 是免費的開源軟體，你的支持是持續更新的動力。")
                }
            } header: {
                Text("支持 Ringwise")
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettings: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "Ringwise")
                            .font(.title2.weight(.bold))
                        Text("一圈一圈，看清你的磁碟。")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                LabeledContent("作者") { Text(verbatim: AppInfo.author) }
                LabeledContent("版本") {
                    Text(verbatim: "\(AppInfo.version) (\(AppInfo.build))").monospacedDigit().textSelection(.enabled)
                }
                LabeledContent("版本類型") { Text(verbatim: AppInfo.localizedEdition) }
                LabeledContent("授權") { Link("MIT 授權", destination: AppInfo.license) }
                LabeledContent("原始碼") { Link(destination: AppInfo.repository) { Text(verbatim: "github.com/PGpenguin72/Ringwise") } }
            }
            Section {
                LabeledContent("隱私權") {
                    Link("隱私權政策", destination: AppInfo.privacy)
                }
                LabeledContent("條款") {
                    Link("使用條款", destination: AppInfo.terms)
                }
                Text("Ringwise 不收集任何資料，也不會自行連上網路。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Text("Ringwise 只使用 Apple 的系統框架，不包含任何第三方套件。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: AppInfo.copyright)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("致謝與版權")
            }
        }
        .formStyle(.grouped)
    }
}

private struct AISettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var ai = model.ai
        Form {
            Section {
                Toggle("用 AI 說明檔案與資料夾", isOn: $ai.isEnabled)
                Text("AI 只會看到路徑、名稱、大小、日期與項目數量，絕不會看到檔案內容。回答僅供參考，Ringwise 不會自動刪除任何東西。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("AI 工具") {
                if ai.isDetecting && ai.providers.isEmpty {
                    HStack { ProgressView().controlSize(.small); Text("正在尋找…") }
                } else if !ai.providers.contains(where: \.isUsable) {
                    Text("目前沒有可用的 AI 工具。").foregroundStyle(.secondary)
                    ForEach(ai.providers.filter { !$0.isUsable }) { p in
                        LabeledContent(p.info.displayName) {
                            Text(p.unavailableReason?.message ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Picker("使用", selection: Binding(
                        get: { ai.currentProvider?.id ?? "" },
                        set: { ai.selectedProviderID = $0 }
                    )) {
                        ForEach(ai.providers.filter(\.isUsable)) { p in
                            Text(p.info.displayName).tag(p.id)
                        }
                    }
                    if let current = ai.currentProvider {
                        ProviderDetails(provider: current)
                        ConsentStatus(date: ai.consentDate(for: current.id),
                                      revoke: { ai.revokeConsent(for: current.id) })
                    }
                    ForEach(ai.providers.filter { !$0.isUsable }) { p in
                        LabeledContent(p.info.displayName) {
                            Text(p.unavailableReason?.message ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("重新偵測", systemImage: "arrow.clockwise") {
                        Task { await ai.detectProviders() }
                    }
                    .disabled(ai.isDetecting)
                }
            }

            Section("進階") {
                if ai.currentProvider?.info.isOnDevice == false {
                    TextField("模型", text: $ai.modelOverride, prompt: Text("使用工具的預設模型"))
                }
                Picker("逾時", selection: $ai.timeout) {
                    ForEach([30.0, 60, 90, 120, 180, 300], id: \.self) { s in
                        Text("\(Int(s)) 秒").tag(s)
                    }
                }
                LabeledContent("回答快取") {
                    HStack {
                        Text("\(ai.cachedCount) 筆").foregroundStyle(.secondary).monospacedDigit()
                        Button("清除 AI 回答快取") { ai.clearCache() }
                            .disabled(ai.cachedCount == 0)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { if !ai.hasDetected { await ai.detectProviders() } }
    }
}

private struct ProviderDetails: View {
    let provider: AIDetectedProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if provider.info.isOnDevice {
                Text("在這台 Mac 上處理，不會傳送任何資料到網路。")
            } else {
                Text("使用你在 \(provider.info.vendor) 的帳號，可能消耗你的用量。")
                if let location = provider.location {
                    Text(location).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }
                if let version = provider.version {
                    Text("版本 \(version)")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct ConsentStatus: View {
    let date: Date?
    let revoke: () -> Void

    var body: some View {
        LabeledContent("同意狀態") {
            if let date {
                HStack {
                    Text("已於 \(date.formatted(date: .abbreviated, time: .shortened)) 同意")
                        .foregroundStyle(.secondary)
                    Button("撤回同意", role: .destructive, action: revoke)
                }
            } else {
                Text("尚未同意（第一次詢問時會先問你）").foregroundStyle(.secondary)
            }
        }
    }
}
