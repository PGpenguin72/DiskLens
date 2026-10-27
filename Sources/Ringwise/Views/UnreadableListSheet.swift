import SwiftUI
import RingwiseCore

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
