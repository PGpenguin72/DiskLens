import SwiftUI
import DiskLensCore

/// Installed apps with everything attributed to them, plus leftovers of removed apps.
struct AppsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var store = model.analysis
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Picker("顯示", selection: $store.showingLeftovers) {
                    Text("已安裝 App").tag(false)
                    Text("殘留檔").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                if store.isRunning { ProgressView().controlSize(.small) }
                Spacer()
                if let report = store.apps {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            StatChip(symbol: "square.grid.2x2.fill", value: report.apps.count.formatted(), caption: String(localized: "個 App"), tint: Theme.used)
                            StatChip(symbol: "sum", value: ByteFormat.string(report.apps.reduce(0) { $0 + $1.total }), caption: String(localized: "App 合計"), tint: .teal)
                            StatChip(symbol: "questionmark.app.dashed", value: ByteFormat.string(report.leftoverTotal), caption: String(localized: "可能的殘留"), tint: .orange)
                        }
                    }
                    .fixedSize()
                }
            }
            if let report = store.apps {
                HStack(alignment: .top, spacing: 12) {
                    if store.showingLeftovers {
                        LeftoverList(groups: report.leftovers)
                            .frame(width: 310)
                        LeftoverDetail()
                    } else {
                        AppList(apps: report.apps)
                            .frame(width: 310)
                        AppDetail()
                    }
                }
            } else {
                ProgressView("正在分析 App…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassCard()
            }
        }
        .task(id: model.revision) { model.refreshAnalysis() }
    }
}

// MARK: - Installed apps

private struct AppList: View {
    let apps: [AppUsage]
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.analysis
        let top = Double(max(apps.first?.total ?? 1, 1))
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(apps) { usage in
                    let selected = store.selectedApp == usage.id
                    Button {
                        store.selectedApp = usage.id
                        model.selection = []
                    } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: IconCache.shared.icon(name: usage.app.path, path: usage.app.path, isDirectory: true))
                                .resizable()
                                .frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(usage.app.name).lineLimit(1)
                                    Spacer(minLength: 6)
                                    Text(ByteFormat.string(usage.total))
                                        .font(.system(.callout, design: .rounded).weight(.semibold))
                                        .monospacedDigit()
                                }
                                StackedBar(sizes: usage.sizes)
                                    .frame(height: 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .scaleEffect(x: max(0.02, Double(usage.total) / top), anchor: .leading)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(selected ? AnyShapeStyle(Theme.used.opacity(0.18)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .help(usage.app.path)
                }
            }
            .padding(8)
        }
        .overlay {
            if apps.isEmpty {
                ContentUnavailableView("沒有找到 App", systemImage: "square.grid.2x2",
                                       description: Text("掃描整個磁碟後，這裡會列出每個 App 佔用的空間。"))
            }
        }
        .frame(maxHeight: .infinity)
        .glassCard()
    }
}

/// Horizontal bar split into bundle / data / cache.
struct StackedBar: View {
    let sizes: [Int64]

    var body: some View {
        let total = Double(max(sizes.reduce(0, +), 1))
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(AppDataKind.allCases, id: \.self) { kind in
                    let s = sizes[kind.rawValue]
                    if s > 0 {
                        Rectangle()
                            .fill(kind.color.gradient)
                            .frame(width: max(1, geo.size.width * Double(s) / total))
                    }
                }
            }
            .clipShape(.capsule)
        }
    }
}

private struct AppDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let usage = model.analysis.selectedAppUsage, let tree = model.tree {
                let _ = model.revision
                HStack(alignment: .top, spacing: 12) {
                    Image(nsImage: IconCache.shared.icon(name: usage.app.path, path: usage.app.path, isDirectory: true))
                        .resizable()
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(usage.app.name)
                            .font(.title2.weight(.semibold))
                            .lineLimit(1)
                        Text(usage.app.bundleID ?? usage.app.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Text(ByteFormat.string(usage.total))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                HStack(spacing: 14) {
                    ForEach(AppDataKind.allCases, id: \.self) { kind in
                        HStack(spacing: 5) {
                            Circle().fill(kind.color).frame(width: 8, height: 8)
                            Text(kind.title).foregroundStyle(.secondary)
                            Text(ByteFormat.string(usage.size(kind))).monospacedDigit()
                        }
                        .font(.callout)
                    }
                    Spacer()
                }
                StackedBar(sizes: usage.sizes).frame(height: 8)
                let caches = Set(usage.locations.filter { $0.kind.dataKind == .cache }.map(\.node))
                HStack(spacing: 8) {
                    Button("選取快取", systemImage: "sparkles") { model.selection = caches }
                        .disabled(caches.isEmpty)
                        .help("只選取快取、記錄檔與視窗狀態，可放心丟到垃圾桶")
                    Button("選取全部資料", systemImage: "checklist") {
                        model.selection = Set(usage.locations.filter { $0.kind != .bundle }.map(\.node))
                    }
                    .help("選取 App 本體以外的所有資料")
                    Spacer()
                    if let bundle = usage.locations.first(where: { $0.kind == .bundle }) {
                        Button("在 Finder 中顯示", systemImage: "arrow.up.forward.app") { model.reveal([bundle.node]) }
                    }
                }
                .buttonStyle(.glass)
                LocationTable(rows: LocationRow.rows(usage.locations, in: tree))
            } else {
                ContentUnavailableView("選擇一個 App", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassCard()
    }
}

// MARK: - Leftovers

private struct LeftoverList: View {
    let groups: [LeftoverGroup]
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.analysis
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(groups) { group in
                    let selected = store.selectedLeftover == group.id
                    Button {
                        store.selectedLeftover = group.id
                        model.selection = []
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "questionmark.app.dashed")
                                .font(.system(size: 22))
                                .foregroundStyle(.orange)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.owner).lineLimit(1).truncationMode(.middle)
                                Text("\(group.locations.count) 個位置")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 6)
                            Text(ByteFormat.string(group.total))
                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(selected ? AnyShapeStyle(Theme.used.opacity(0.18)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView("沒有發現殘留檔", systemImage: "checkmark.seal",
                                       description: Text("找不到明顯屬於已移除 App 的資料。"))
            }
        }
        .frame(maxHeight: .infinity)
        .glassCard()
    }
}

private struct LeftoverDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("可能是已移除 App 的殘留", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("這些資料夾的識別碼不屬於任何已安裝的 App，也不是 Apple 系統元件。DiskLens 判斷得很保守，但仍請確認不再需要後再丟到垃圾桶。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let group = model.analysis.selectedLeftoverGroup, let tree = model.tree {
                let _ = model.revision
                HStack(spacing: 8) {
                    Text(group.owner)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    Text(ByteFormat.string(group.total))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                HStack(spacing: 8) {
                    Button("全選這一組", systemImage: "checklist") { model.selection = Set(group.locations.map(\.node)) }
                    Button("全選所有殘留", systemImage: "checklist.checked") {
                        model.selection = Set((model.analysis.apps?.leftovers ?? []).flatMap { $0.locations.map(\.node) })
                    }
                    Spacer()
                }
                .buttonStyle(.glass)
                LocationTable(rows: LocationRow.rows(group.locations, in: tree))
            } else {
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassCard()
    }
}

// MARK: - Locations table

/// One attributed node with its location label.
struct LocationRow: Identifiable {
    let file: FileRow
    let kind: String
    var id: NodeID { file.id }

    static func rows(_ locations: [AppLocation], in tree: FileTree) -> [LocationRow] {
        let live = locations.filter { tree.isLive($0.node) }
        let files = FileRow.list(live.map(\.node), in: tree)
        return zip(files, live).map { LocationRow(file: $0, kind: $1.kind.title) }
    }
}

private struct LocationTable: View {
    let rows: [LocationRow]
    @Environment(AppModel.self) private var model

    var body: some View {
        Table(rows, selection: model.tableSelection) {
            TableColumn("名稱") { row in
                NameCell(row: row.file, checked: model.multiSelectMode ? model.selection.contains(row.id) : nil,
                         onToggle: { model.checkCircleTapped(row.id) })
            }
            .width(min: 140, ideal: 200)
            TableColumn("類別") { row in
                Text(row.kind).foregroundStyle(.secondary).lineLimit(1)
            }
            .width(92)
            TableColumn("大小") { SizeCell(size: $0.file.size) }
                .width(80)
            TableColumn("位置") { row in
                Text(row.file.folder)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .help(row.file.path)
            }
            .width(min: 100, ideal: 220)
        }
        .scrollContentBackground(.hidden)
        .alternatingRowBackgrounds(.disabled)
        .overlayScrollers()
        .contextMenu(forSelectionType: NodeID.self) { ids in
            FileContextMenu(ids: ids, showsBrowserItem: true)
        } primaryAction: { ids in
            model.primaryAction(ids)
        }
    }
}
