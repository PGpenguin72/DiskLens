import SwiftUI
import DiskLensCore

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let selection = Binding<SidebarItem?>(
            get: { model.sidebar },
            set: { if let item = $0, item.isAvailable { model.sidebar = item } }
        )
        List(selection: selection) {
            Section("瀏覽") {
                ForEach(SidebarItem.allCases.filter(\.isAvailable)) { item in
                    Label(item.title, systemImage: item.symbol)
                        .tag(item)
                }
            }
            Section("即將推出") {
                ForEach(SidebarItem.allCases.filter { !$0.isAvailable }) { item in
                    Label(item.title, systemImage: item.symbol)
                        .foregroundStyle(.tertiary)
                        .selectionDisabled()
                        .help("即將推出")
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let volume = model.volume {
                VolumeCard(volume: volume, snapshotCount: model.snapshotCount ?? 0)
                    .padding(10)
            }
        }
    }
}

/// Compact capacity ring for the bottom of the sidebar.
private struct VolumeCard: View {
    let volume: VolumeInfo
    let snapshotCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                CapacityGauge(volume: volume, lineWidth: 7, showsCaption: false)
                    .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 1) {
                    Text(volume.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ByteFormat.string(volume.available))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text("共 \(ByteFormat.string(volume.total))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
            }
            CapacityLegend(volume: volume, axis: .vertical)
            if snapshotCount > 0 {
                Label("本機快照 \(snapshotCount) 個", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Time Machine 本機快照佔用的空間不會顯示為檔案；macOS 會在空間不足時自動刪除。")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18)
    }
}
