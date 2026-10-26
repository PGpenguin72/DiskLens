import SwiftUI
import DiskLensCore

/// Volume capacity summary plus the scan buttons.
struct OverviewHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            if let volume = model.volume {
                VolumeSummary(volume: volume, snapshotCount: model.snapshotCount ?? 0)
            } else {
                Text("無法讀取磁碟資訊").foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            ScanButtons()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background.secondary)
    }
}

private struct VolumeSummary: View {
    let volume: VolumeInfo
    let snapshotCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(volume.name).font(.headline)
                Text("可用 \(ByteFormat.string(volume.available))，共 \(ByteFormat.string(volume.total))")
                    .foregroundStyle(.secondary)
            }
            CapacityBar(volume: volume)
                .frame(height: 8)
                .frame(maxWidth: 520)
            HStack(spacing: 14) {
                LegendItem(color: .accentColor, text: "已使用 \(ByteFormat.string(volume.used - volume.purgeable))")
                if volume.purgeable > 0 {
                    LegendItem(color: .accentColor.opacity(0.4), text: "可清除 \(ByteFormat.string(volume.purgeable))")
                        .help("macOS 可在需要時自動釋放的空間（快取、iCloud 檔案等）。")
                }
                LegendItem(color: .secondary.opacity(0.35), text: "可用 \(ByteFormat.string(volume.available))")
                if snapshotCount > 0 {
                    Label("本機快照 \(snapshotCount) 個", systemImage: "clock.arrow.circlepath")
                        .help("Time Machine 本機快照佔用的空間不會顯示為檔案；macOS 會在空間不足時自動刪除。")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

/// Used / purgeable / free capacity bar.
private struct CapacityBar: View {
    let volume: VolumeInfo

    var body: some View {
        GeometryReader { geo in
            let total = Double(max(volume.total, 1))
            let used = Double(volume.used - volume.purgeable) / total
            let purgeable = Double(volume.purgeable) / total
            HStack(spacing: 0) {
                Rectangle().fill(Color.accentColor)
                    .frame(width: geo.size.width * used)
                Rectangle().fill(Color.accentColor.opacity(0.4))
                    .frame(width: geo.size.width * purgeable)
                Spacer(minLength: 0)
            }
            .background(.quaternary)
            .clipShape(Capsule())
        }
    }
}

private struct LegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).monospacedDigit()
        }
    }
}

/// "Scan whole disk" / "Choose folder…" or, while scanning, "Cancel".
struct ScanButtons: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            if model.isScanning {
                Button("取消掃描", systemImage: "xmark.circle") { model.cancelScan() }
            } else {
                Button("選擇資料夾…", systemImage: "folder") { model.chooseFolderAndScan() }
                Button("掃描整個磁碟", systemImage: "magnifyingglass") { model.scanWholeDisk() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.large)
    }
}
