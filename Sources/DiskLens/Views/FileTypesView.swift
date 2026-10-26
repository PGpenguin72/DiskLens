import SwiftUI
import Charts
import DiskLensCore

/// Breakdown of all files by kind; picking a kind lists its largest files.
struct FileTypesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var store = model.analysis
        VStack(spacing: 12) {
            if let report = store.fileTypes {
                BreakdownCard(report: report, selected: store.selectedCategory) { store.selectCategory($0) }
                let category = report.total(store.selectedCategory)
                HStack(spacing: 8) {
                    Image(systemName: store.selectedCategory.symbol).foregroundStyle(store.selectedCategory.color)
                    Text("最大的\(store.selectedCategory.title)檔案").fontWeight(.semibold).lineLimit(1)
                    Text("共 \(category.count, format: .number) 個 · \(ByteFormat.string(category.size))")
                        .foregroundStyle(.secondary)
                    if store.categoryRows.count >= 500 {
                        Text("（只顯示最大的 500 個）").foregroundStyle(.tertiary)
                    }
                    if store.isRunning { ProgressView().controlSize(.small) }
                }
                .padding(.horizontal, 16)
                .frame(height: 36)
                .glassEffect(.regular, in: .capsule)
                .frame(maxWidth: .infinity, alignment: .leading)
                FileListTable(rows: store.categoryRows, sortOrder: $store.categorySort)
                    .glassCard()
                    .overlay {
                        if store.categoryRows.isEmpty {
                            ContentUnavailableView("沒有這類檔案", systemImage: store.selectedCategory.symbol)
                        }
                    }
            } else {
                ProgressView("正在分類檔案…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassCard()
            }
        }
        .task(id: model.revision) { model.refreshAnalysis() }
    }
}

/// Donut chart plus a clickable legend of all categories.
private struct BreakdownCard: View {
    let report: FileTypeReport
    let selected: FileCategory
    let onSelect: (FileCategory) -> Void
    @State private var angle: Int64?

    var body: some View {
        let total = max(report.totalSize, 1)
        let slices = report.totals.filter { $0.size > 0 }
        HStack(spacing: 20) {
            Chart(slices, id: \.category) { item in
                SectorMark(angle: .value("大小", item.size), innerRadius: .ratio(0.62), angularInset: 1.5)
                    .cornerRadius(4)
                    .foregroundStyle(item.category.color.gradient)
                    .opacity(item.category == selected ? 1 : 0.55)
            }
            .chartLegend(.hidden)
            .chartAngleSelection(value: $angle)
            .chartBackground { _ in
                VStack(spacing: 0) {
                    Text(ByteFormat.string(report.totalSize))
                        .font(.system(.headline, design: .rounded))
                        .monospacedDigit()
                    Text("所有檔案").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 170, height: 170)
            .onChange(of: angle) { _, value in
                guard let value else { return }
                var running: Int64 = 0
                for item in slices {
                    running += item.size
                    if value <= running { onSelect(item.category); break }
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 4) {
                ForEach(report.totals, id: \.category) { item in
                    Button { onSelect(item.category) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.category.symbol)
                                .foregroundStyle(item.category.color)
                                .frame(width: 20)
                            Text(item.category.title).lineLimit(1).minimumScaleFactor(0.85)
                            Spacer(minLength: 4)
                            Text(ByteFormat.string(item.size))
                                .monospacedDigit()
                                .fontWeight(.semibold)
                            Text(Double(item.size) / Double(total), format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(item.category == selected ? AnyShapeStyle(item.category.color.opacity(0.2)) : AnyShapeStyle(.clear),
                                    in: .rect(cornerRadius: 10))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .help(Text("\(item.count, format: .number) 個檔案"))
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}
