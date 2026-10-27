import SwiftUI
import DiskLensCore

/// Path + stats on top; sunburst card and table card side by side.
struct FolderBrowserView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                BreadcrumbBar()
                ScanStats()
            }
            HStack(alignment: .top, spacing: 12) {
                // The AI panel takes the right side; give its width to the table instead of the chart.
                if !model.ai.showingPanel {
                    ChartCard()
                        .frame(width: 330)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                FolderTable()
                    .glassCard()
            }
        }
    }
}

/// Clickable path from the scan root to the current folder, in a glass capsule.
private struct BreadcrumbBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let crumbs = model.breadcrumb
        HStack(spacing: 6) {
            Button("上層資料夾", systemImage: "arrow.up") { model.goUp() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(!model.canGoUp)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(crumbs.enumerated()), id: \.element) { index, id in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            let isLast = index == crumbs.count - 1
                            Button {
                                model.open(id)
                            } label: {
                                Text(name(id))
                                    .fontWeight(isLast ? .semibold : .regular)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(isLast ? AnyShapeStyle(.primary.opacity(0.08)) : AnyShapeStyle(.clear), in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(isLast ? .primary : .secondary)
                            .id(id)
                        }
                    }
                }
                .onChange(of: crumbs.last) { _, last in
                    if let last { proxy.scrollTo(last, anchor: .trailing) }
                }
            }
            if model.isSortingFolder {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .glassEffect(.regular, in: .capsule)
    }

    private func name(_ id: NodeID) -> String {
        model.tree?.displayName(id, volumeName: model.volume?.name) ?? ""
    }
}

/// Glass chips with the current folder's totals and scan statistics.
private struct ScanStats: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let tree = model.tree, let dir = model.currentDir {
            let _ = model.revision
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    StatChip(symbol: "internaldrive.fill", value: ByteFormat.string(tree.size(dir)), caption: String(localized: "這個資料夾"), tint: Theme.used)
                    StatChip(symbol: "doc.on.doc.fill", value: tree.fileCount(dir).formatted(), caption: String(localized: "個檔案"), tint: .teal)
                    StatChip(symbol: "bolt.fill", value: scanSeconds, caption: String(localized: "掃描耗時"), tint: .yellow)
                    if model.unreadableCount > 0 {
                        Button {
                            model.showingUnreadable = true
                        } label: {
                            StatChip(symbol: "exclamationmark.triangle.fill", value: model.unreadableCount.formatted(), caption: String(localized: "讀不到"), tint: .orange)
                        }
                        .buttonStyle(.plain)
                        .help("查看無法讀取的資料夾")
                    }
                }
            }
            .fixedSize()
        }
    }

    private var scanSeconds: String {
        let seconds = (model.scanDuration ?? 0).formatted(.number.precision(.fractionLength(1)))
        return String(localized: "\(seconds) 秒")
    }
}

/// Sunburst plus legend of the biggest items.
private struct ChartCard: View {
    var body: some View {
        VStack(spacing: 10) {
            SunburstView()
                .padding(.horizontal, 6)
            Divider().opacity(0.5)
            SunburstLegend()
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxHeight: .infinity)
        .glassCard()
    }
}

/// Lazy table of the current folder; rows are precomputed by the model.
private struct FolderTable: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Table(model.folderRows, selection: model.tableSelection, sortOrder: $model.folderSort) {
            TableColumn("名稱", value: \.name) { row in
                NameCell(row: row, dotColor: model.chartColorIndex[row.id].map(Theme.color),
                         checked: model.multiSelectMode ? model.selection.contains(row.id) : nil,
                         onToggle: { model.checkCircleTapped(row.id) })
                    .onHover { inside in
                        if inside { model.highlighted = row.id } else if model.highlighted == row.id { model.highlighted = nil }
                    }
            }
            .width(min: 100, ideal: 130)
            TableColumn("大小", value: \.size) { SizeCell(size: $0.size) }
                .width(85)
            TableColumn("比例") { row in
                SizeBarCell(fraction: row.fraction, color: model.chartColorIndex[row.id].map(Theme.color))
            }
            .width(100)
            TableColumn("項目數", value: \.fileCount) { CountCell(row: $0) }
                .width(72)
            TableColumn("修改日期", value: \.modified) { DateCell(row: $0) }
                .width(92)
        }
        .scrollContentBackground(.hidden)
        .alternatingRowBackgrounds(.disabled)
        .overlayScrollers()
        .padding(6)
        .contextMenu(forSelectionType: NodeID.self) { ids in
            FileContextMenu(ids: ids)
        } primaryAction: { ids in
            model.primaryAction(ids)
        }
        .overlay {
            if model.folderRows.isEmpty {
                ContentUnavailableView("空的資料夾", systemImage: "folder")
            }
        }
    }
}
