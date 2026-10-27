import SwiftUI
import RingwiseCore

/// Rule-based list of reclaimable space. Items are only selected here; trashing goes through
/// the selection dock and its confirmation.
struct CleanupView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.analysis
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Label("Ringwise 不會自動刪除任何東西：選取項目後，再用下方的「丟到垃圾桶」。", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if store.isRunning { ProgressView().controlSize(.small) }
                Spacer(minLength: 8)
                if let rules = store.cleanup {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            StatChip(symbol: "sparkles", value: ByteFormat.string(store.cleanupTotal), caption: String(localized: "可清理"), tint: .green)
                            StatChip(symbol: "list.bullet", value: rules.count.formatted(), caption: String(localized: "個類別"), tint: Theme.used)
                        }
                    }
                    .fixedSize()
                }
            }
            if let rules = store.cleanup {
                HStack(alignment: .top, spacing: 12) {
                    RuleList(rules: rules)
                        .frame(width: 320)
                    RuleDetail()
                }
            } else {
                ProgressView("正在尋找可清理的項目…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassCard()
            }
        }
        .task(id: model.revision) { model.refreshAnalysis() }
    }
}

private struct RuleList: View {
    let rules: [CleanupMatch]
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.analysis
        ScrollView {
            // A plain VStack: ~20 cards, and a lazy stack re-measuring them made the list jump on every click.
            VStack(spacing: 4) {
                ForEach(rules) { match in
                    let selected = store.selectedRule == match.rule
                    Button {
                        store.selectRule(match.rule)
                        model.selection = []
                    } label: {
                        RuleCard(match: match)
                            .background(selected ? AnyShapeStyle(Theme.used.opacity(0.18)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .overlay {
            if rules.isEmpty {
                ContentUnavailableView("沒有找到可清理的項目", systemImage: "checkmark.seal")
            }
        }
        .frame(maxHeight: .infinity)
        .glassCard()
    }
}

private struct RuleCard: View {
    let match: CleanupMatch

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: match.rule.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(match.rule.safety.color)
                .frame(width: 30, height: 30)
                .background(match.rule.safety.color.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(match.rule.title)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                    Text(ByteFormat.string(match.total))
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                CleanupSafetyBadge(safety: match.rule.safety, short: true)
                Text(match.rule.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

private struct CleanupSafetyBadge: View {
    let safety: CleanupSafety
    var short = false

    var body: some View {
        Label(short ? safety.shortTitle : safety.title, systemImage: safety.symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(safety.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(safety.color.opacity(0.14), in: .capsule)
    }
}

private struct RuleDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var store = model.analysis
        VStack(alignment: .leading, spacing: 10) {
            if let match = store.selectedRuleMatch {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(match.rule.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(ByteFormat.string(match.total))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                CleanupSafetyBadge(safety: match.rule.safety)
                // Fixed two-line height so the table below doesn't move when switching rules.
                Text(match.rule.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .help(match.rule.summary)
                HStack(spacing: 8) {
                    if match.rule.isActionable {
                        Button("全選這一類", systemImage: "checklist") { model.selection = Set(match.items) }
                            .buttonStyle(.glassProminent)
                    } else {
                        Button("打開垃圾桶", systemImage: "trash") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: UserHome.path + "/.Trash"))
                        }
                        .buttonStyle(.glassProminent)
                        Text("請在 Finder 中清空垃圾桶。").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(match.items.count) 個項目").foregroundStyle(.secondary)
                }
                FileListTable(rows: store.ruleRows, sortOrder: $store.ruleSort, compact: true)
                    .padding(-6)
            } else {
                ContentUnavailableView("選擇一個類別", systemImage: "sparkles")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassCard()
    }
}
