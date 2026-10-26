import SwiftUI
import DiskLensCore

/// Flat list of nodes from anywhere in the tree (large files, search results).
struct FileListTable: View {
    let rows: [FileRow]
    @Binding var sortOrder: [KeyPathComparator<FileRow>]
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Table(rows, selection: $model.selection, sortOrder: $sortOrder) {
            TableColumn("名稱", value: \.name) { NameCell(row: $0) }
                .width(min: 160, ideal: 280)
            TableColumn("大小", value: \.size) { SizeCell(size: $0.size) }
                .width(min: 70, ideal: 90, max: 130)
            TableColumn("位置", value: \.folder) { row in
                Text(row.folder)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .help(row.folder)
            }
            .width(min: 160, ideal: 360)
            TableColumn("修改日期", value: \.modified) { DateCell(row: $0) }
                .width(min: 110, ideal: 150, max: 200)
        }
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
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("最小大小", selection: $model.largeFilesMinimum) {
                    ForEach(MinimumSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                if model.isLoadingLargeFiles {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Text("最大的 \(model.largeRows.count) 個檔案，合計 \(ByteFormat.string(model.largeRows.reduce(0) { $0 + $1.size }))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            Divider()
            FileListTable(rows: model.largeRows, sortOrder: $model.largeSort)
                .overlay {
                    if model.largeRows.isEmpty && !model.isLoadingLargeFiles {
                        ContentUnavailableView("沒有符合條件的檔案", systemImage: "doc")
                    }
                }
        }
    }
}

struct SearchResultsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if model.isSearching {
                    ProgressView().controlSize(.small)
                    Text("搜尋中…")
                } else {
                    Text("「\(model.searchText)」：\(model.searchRows.count) 個結果")
                    if model.searchRows.count >= 1000 {
                        Text("（只顯示最大的 1000 個）").foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            Divider()
            FileListTable(rows: model.searchRows, sortOrder: $model.searchSort)
                .overlay {
                    if model.searchRows.isEmpty && !model.isSearching {
                        ContentUnavailableView.search(text: model.searchText)
                    }
                }
        }
    }
}
