import SwiftUI
import DiskLensCore

/// Bottom bar: selection summary on the left, scan statistics on the right.
struct StatusBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            SelectionSummary()
            Spacer()
            if model.isPerformingAction {
                ProgressView().controlSize(.mini)
                Text("處理中…")
            }
            if model.isScanning {
                Text("掃描中：\(model.progress.itemsScanned, format: .number) 個項目")
            } else if model.hasTree {
                Text("\(model.nodeCount, format: .number) 個項目・掃描耗時 \(formattedDuration)")
                if model.unreadableCount > 0 {
                    Button {
                        model.showingUnreadable = true
                    } label: {
                        Label("\(model.unreadableCount) 個資料夾無法讀取", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.borderless)
                    .help("查看無法讀取的資料夾")
                }
            }
        }
        .font(.callout)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var formattedDuration: String {
        let seconds = model.scanDuration ?? 0
        return seconds < 60
            ? String(format: "%.1f 秒", seconds)
            : Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}

/// Isolated so that selection changes only re-render this text.
private struct SelectionSummary: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let summary = model.selectionSummary
        if summary.count == 0 {
            Text(model.hasTree ? "未選取項目" : "")
        } else {
            Text("已選取 \(summary.count, format: .number) 個項目，共 \(ByteFormat.string(summary.size))")
        }
    }
}

/// List of folders the scanner could not read.
struct UnreadableListSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let paths = model.tree?.unreadable ?? []
        VStack(alignment: .leading, spacing: 12) {
            Text("無法讀取的資料夾（\(paths.count) 個）").font(.headline)
            Text("這些資料夾的大小沒有計入。多半是因為缺少「完整磁碟取用權限」，或是受 macOS 保護的系統資料夾。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            List(paths, id: \.self) { path in
                Text(path)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(path)
            }
            .listStyle(.bordered)
            HStack {
                if !model.hasFullDiskAccess {
                    Button("開啟完整磁碟取用權限設定") { FullDiskAccess.openSettings() }
                }
                Button("拷貝清單") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
                }
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 620, height: 460)
    }
}
