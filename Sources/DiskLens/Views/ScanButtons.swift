import SwiftUI

/// "Scan whole disk" / "Choose folder…" or, while scanning, "Cancel".
struct ScanButtons: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                if model.isScanning {
                    Button("取消掃描", systemImage: "xmark") { model.cancelScan() }
                        .buttonStyle(.glass)
                        .keyboardShortcut(.cancelAction)
                } else {
                    Button("選擇資料夾…", systemImage: "folder") { model.chooseFolderAndScan() }
                        .buttonStyle(.glass)
                    Button("掃描整個磁碟", systemImage: "sparkle.magnifyingglass") { model.scanWholeDisk() }
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .controlSize(.extraLarge)
    }
}
