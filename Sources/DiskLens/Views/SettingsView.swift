import SwiftUI
import DiskLensCore

/// Settings window (⌘,): a General placeholder and the AI section.
struct SettingsView: View {
    enum Pane: Hashable { case general, ai }
    @State var pane: Pane = .ai

    var body: some View {
        TabView(selection: $pane) {
            Tab("一般", systemImage: "gearshape", value: .general) {
                GeneralSettings()
            }
            Tab("AI", systemImage: "sparkles", value: .ai) {
                AISettings()
            }
        }
        .frame(width: 560, height: 520)
    }
}

private struct GeneralSettings: View {
    var body: some View {
        Form {
            Section {
                Text("之後會在這裡加入一般設定。")
                    .foregroundStyle(.secondary)
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
                Text("AI 只會看到路徑、名稱、大小、日期與項目數量，絕不會看到檔案內容。回答僅供參考，DiskLens 不會自動刪除任何東西。")
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
