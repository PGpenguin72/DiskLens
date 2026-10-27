import SwiftUI
import RingwiseCore

/// Flat list of nodes from anywhere in the tree (large files, search results).
struct FileListTable: View {
    let rows: [FileRow]
    @Binding var sortOrder: [KeyPathComparator<FileRow>]
    /// Hides the date column, for narrow panes.
    var compact = false
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Table(rows, selection: model.tableSelection, sortOrder: $sortOrder) {
            TableColumn("名稱", value: \.name) { row in
                NameCell(row: row, checked: model.multiSelectMode ? model.selection.contains(row.id) : nil,
                         onToggle: { model.checkCircleTapped(row.id) })
            }
                .width(min: 160, ideal: 280)
            TableColumn("大小", value: \.size) { SizeCell(size: $0.size) }
                .width(85)
            TableColumn("位置", value: \.folder) { row in
                Text(row.folder)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .help(row.folder)
            }
            .width(min: 160, ideal: 360)
            if !compact {
                TableColumn("修改日期", value: \.modified) { DateCell(row: $0) }
                    .width(92)
            }
        }
        .scrollContentBackground(.hidden)
        .alternatingRowBackgrounds(.disabled)
        .overlayScrollers()
        .padding(6)
        .contextMenu(forSelectionType: NodeID.self) { ids in
            FileContextMenu(ids: ids, showsBrowserItem: true)
        } primaryAction: { ids in
            model.primaryAction(ids)
        }
    }
}

struct LargeFilesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Picker("最小大小", selection: $model.largeFilesMinimum) {
                    ForEach(MinimumSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                if model.isLoadingLargeFiles {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                StatChip(symbol: "arrow.up.doc.fill", value: model.largeRows.count.formatted(), caption: String(localized: "最大的檔案"), tint: .pink)
                StatChip(symbol: "sum", value: ByteFormat.string(model.largeRows.reduce(0) { $0 + $1.size }), caption: String(localized: "合計"), tint: Theme.used)
            }
            TopFilesStrip(rows: Array(model.largeRows.prefix(6)))
            FileListTable(rows: model.largeRows, sortOrder: $model.largeSort)
                .glassCard()
                .overlay {
                    if model.largeRows.isEmpty && !model.isLoadingLargeFiles {
                        ContentUnavailableView("沒有符合條件的檔案", systemImage: "doc")
                    }
                }
        }
    }
}

/// The biggest files as glass tiles with a size bar — the "wow, that's where it went" row.
private struct TopFilesStrip: View {
    let rows: [FileRow]
    @Environment(AppModel.self) private var model

    var body: some View {
        if let top = rows.first?.size, top > 0 {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        Button {
                            model.selection = [row.id]
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(nsImage: IconCache.shared.icon(name: row.name, path: row.path, isDirectory: row.isDirectory))
                                        .resizable()
                                        .frame(width: 22, height: 22)
                                    Text(ByteFormat.string(row.size))
                                        .font(.system(.headline, design: .rounded))
                                        .monospacedDigit()
                                }
                                Text(row.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Capsule()
                                    .fill(Theme.color(index).gradient)
                                    .frame(height: 5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .scaleEffect(x: Double(row.size) / Double(top), anchor: .leading)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                        .help(row.path)
                    }
                }
            }
        }
    }
}

struct SearchResultsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                if model.isSearching {
                    ProgressView().controlSize(.small)
                    Text("搜尋中…")
                } else {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    Text("「\(model.searchText)」").fontWeight(.semibold)
                    Text("\(model.searchRows.count) 個結果").foregroundStyle(.secondary)
                    if model.searchRows.count >= 1000 {
                        Text("（只顯示最大的 1000 個）").foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .glassEffect(.regular, in: .capsule)
            .frame(maxWidth: .infinity, alignment: .leading)
            FileListTable(rows: model.searchRows, sortOrder: $model.searchSort)
                .glassCard()
                .overlay {
                    if model.searchRows.isEmpty && !model.isSearching {
                        ContentUnavailableView.search(text: model.searchText)
                    }
                }
        }
    }
}
