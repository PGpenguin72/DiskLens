import SwiftUI
import DiskLensCore

/// Shown before the first scan finishes: call to action, live progress, or the last error.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.scanState {
        case .scanning:
            ScanProgressPanel()
        case .failed(let message):
            ContentUnavailableView {
                Label("掃描失敗", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                ScanButtons()
            }
        case .idle, .finished:
            ContentUnavailableView {
                Label("找出佔用空間的檔案", systemImage: "internaldrive")
            } description: {
                Text("掃描整個磁碟或某個資料夾，依大小列出所有內容。檔案只會移到垃圾桶，不會直接刪除。")
            } actions: {
                ScanButtons()
            }
        }
    }
}

/// Live scan progress: items, elapsed time, current path.
struct ScanProgressPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("正在掃描「\(model.scanRootDisplayName)」…")
                .font(.title3.weight(.semibold))
            if let fraction {
                ProgressView(value: fraction)
            } else {
                ProgressView().progressViewStyle(.linear)
            }
            HStack {
                Text("已掃描 \(model.progress.itemsScanned, format: .number) 個項目")
                if model.progress.bytesScanned > 0 {
                    Text("· \(ByteFormat.string(model.progress.bytesScanned))")
                }
                Spacer()
                Text("經過時間 \(Duration.seconds(model.scanElapsed).formatted(.time(pattern: .minuteSecond)))")
            }
            .monospacedDigit()
            .foregroundStyle(.secondary)
            Text(model.progress.currentPath)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack {
                Spacer()
                Button("取消") { model.cancelScan() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(maxWidth: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(24)
    }

    /// Determinate progress when scanning the whole disk (bytes found vs. used space).
    private var fraction: Double? {
        guard model.scanRoot?.path == "/", let volume = model.volume, volume.used > 0,
              model.progress.bytesScanned > 0 else { return nil }
        return min(1, Double(model.progress.bytesScanned) / Double(volume.used))
    }
}
