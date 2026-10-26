import SwiftUI
import DiskLensCore

/// Breadcrumb + table of the current folder's children.
struct FolderBrowserView: View {
    var body: some View {
        VStack(spacing: 0) {
            BreadcrumbBar()
            Divider()
            FolderTable()
        }
    }
}

/// Clickable path from the scan root to the current folder.
private struct BreadcrumbBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let crumbs = model.breadcrumb
        HStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(crumbs.enumerated()), id: \.element) { index, id in
                            if index > 0 {
                                Image(systemName: "chevron.compact.right").foregroundStyle(.tertiary)
                            }
                            Button {
                                model.open(id)
                            } label: {
                                Text(name(id))
                                    .fontWeight(index == crumbs.count - 1 ? .semibold : .regular)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(index == crumbs.count - 1 ? .primary : .secondary)
                            .id(id)
                        }
                    }
                }
                .onChange(of: crumbs.last) { _, last in
                    if let last { proxy.scrollTo(last, anchor: .trailing) }
                }
            }
            Spacer(minLength: 8)
            if model.isSortingFolder {
                ProgressView().controlSize(.small)
            }
            if let tree = model.tree, let dir = model.currentDir {
                let _ = model.revision
                Text("\(ByteFormat.string(tree.size(dir)))・\(tree.fileCount(dir), format: .number) 個檔案")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
    }

    private func name(_ id: NodeID) -> String {
        model.tree?.displayName(id, volumeName: model.volume?.name) ?? ""
    }
}

/// Lazy table of the current folder; rows are precomputed by the model.
private struct FolderTable: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Table(model.folderRows, selection: $model.selection, sortOrder: $model.folderSort) {
            TableColumn("名稱", value: \.name) { NameCell(row: $0) }
                .width(min: 180, ideal: 340)
            TableColumn("大小", value: \.size) { SizeCell(size: $0.size) }
                .width(min: 70, ideal: 90, max: 130)
            TableColumn("比例") { SizeBarCell(fraction: $0.fraction) }
                .width(min: 90, ideal: 120, max: 160)
            TableColumn("項目數", value: \.fileCount) { CountCell(row: $0) }
                .width(min: 60, ideal: 80, max: 120)
            TableColumn("修改日期", value: \.modified) { DateCell(row: $0) }
                .width(min: 110, ideal: 150, max: 200)
        }
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
