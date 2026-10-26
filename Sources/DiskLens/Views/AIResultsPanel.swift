import SwiftUI
import DiskLensCore

/// Inspector with the AI's explanations. Display-only: actions here are the user's own clicks.
struct AIResultsPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let panel = model.ai.panel
        VStack(spacing: 0) {
            header(panel)
            ScrollView { cards(panel) }
            footer(panel)
        }
    }

    private func cards(_ panel: AIPanel) -> some View {
        let ai = model.ai
        return VStack(alignment: .leading, spacing: 12) {
            if let notice = panel.notice {
                Label(notice, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if panel.isLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("正在詢問 \(panel.providerName)…")
                    Spacer()
                    Button("取消") { ai.cancel() }
                        .buttonStyle(.glass)
                }
                .padding(12)
                .glassCard(cornerRadius: 14)
            }
            if let error = panel.error {
                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    if !panel.items.isEmpty {
                        Button("重試", systemImage: "arrow.clockwise") { ai.askAgain() }
                            .buttonStyle(.glass)
                    }
                }
                .padding(12)
                .glassCard(cornerRadius: 14)
            }
            ForEach(panel.items) { entry in
                AIAnswerCard(item: entry.item, answer: panel.answers[entry.item.path],
                             isLoading: panel.isLoading, provider: panel.providerName,
                             reveal: { model.reveal([entry.node]) },
                             select: { model.selectAIItem(entry.node) })
            }
        }
        .padding(14)
    }

    private func header(_ panel: AIPanel) -> some View {
        HStack {
            Label("AI 說明", systemImage: "sparkles")
                .font(.headline)
            Spacer()
            if !panel.providerName.isEmpty {
                Text(panel.providerName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
            }
            Button("關閉", systemImage: "xmark") { model.ai.showingPanel = false }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
        }
        .padding(14)
    }

    private func footer(_ panel: AIPanel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !panel.items.isEmpty && !panel.isLoading {
                HStack {
                    if panel.fromCache {
                        Text("這是之前的回答").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("重新詢問", systemImage: "arrow.clockwise") { model.ai.askAgain() }
                        .buttonStyle(.glass)
                }
            }
            Text("AI 的回答僅供參考，可能有誤。DiskLens 不會自動刪除任何檔案。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
    }
}

/// One explained item. Takes plain values only.
private struct AIAnswerCard: View {
    let item: AIItem
    let answer: AIExplanation?
    let isLoading: Bool
    let provider: String
    let reveal: () -> Void
    let select: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundStyle(item.isDirectory ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).font(.body.weight(.semibold)).lineLimit(1)
                    Text(ByteFormat.string(item.size)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer()
                if let answer { SafetyBadge(safety: answer.safety) }
            }
            Text(item.path)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)

            if let answer {
                Text(answer.what)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let owner = answer.owner {
                    LabeledLine(title: "來源", value: owner)
                }
                if !answer.impact.isEmpty {
                    LabeledLine(title: "刪除後", value: answer.impact)
                }
                HStack(spacing: 8) {
                    Text("把握度 \(answer.confidence, format: .percent.precision(.fractionLength(0)))")
                    Text("·")
                    Text("由 \(provider) 回答")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else if isLoading {
                Text("等待回答…").font(.callout).foregroundStyle(.secondary)
            } else {
                Text("沒有收到這個項目的回答。").font(.callout).foregroundStyle(.secondary)
            }

            HStack {
                Button("在 Finder 中顯示", systemImage: "arrow.up.forward.app", action: reveal)
                Button("選取", systemImage: "checkmark.circle", action: select)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 16, tint: answer.map { SafetyBadge.color($0.safety).opacity(0.08) })
    }
}

private struct LabeledLine: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 🟢 / 🟡 / 🔴 capsule.
struct SafetyBadge: View {
    let safety: AISafety

    static func color(_ safety: AISafety) -> Color {
        switch safety {
        case .safe: .green
        case .caution: .yellow
        case .keep: .red
        }
    }

    var body: some View {
        Group {
            switch safety {
            case .safe: Text("🟢 可安全刪除")
            case .caution: Text("🟡 刪除前請注意")
            case .keep: Text("🔴 建議保留")
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Self.color(safety).opacity(0.18), in: .capsule)
    }
}

/// Consent sheet, "no provider" sheet and the results inspector, attached to the main window.
struct AIPresentation: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        @Bindable var ai = model.ai
        content
            .inspector(isPresented: $ai.showingPanel) {
                AIResultsPanel()
                    .inspectorColumnWidth(min: 320, ideal: 380, max: 520)
            }
            .sheet(item: $ai.consentRequest) { request in
                AIConsentSheet(request: request,
                               onAccept: { ai.acceptConsent(request) },
                               onDecline: { ai.declineConsent() })
            }
            .sheet(isPresented: $ai.showingNoProvider) {
                AINoProviderSheet(reasons: Dictionary(uniqueKeysWithValues: ai.providers.compactMap { p in
                    p.unavailableReason.map { (p.id, $0.message) }
                })) { ai.showingNoProvider = false }
            }
    }
}
