import SwiftUI

/// "About DiskLens" window: icon, version, author, links and license.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 112, height: 112)
                    .shadow(color: Theme.used.opacity(0.45), radius: 24, y: 8)
                VStack(spacing: 4) {
                    Text(verbatim: "DiskLens")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("版本 \(AppInfo.version)（\(AppInfo.build)）")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .textSelection(.enabled)
                }
                Text("看見磁碟空間都跑去哪了。")
                    .font(.title3)
                Text("由 \(AppInfo.author) 設計與開發")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 34)

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Link(destination: AppInfo.repository) {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    .buttonStyle(.glass)
                    Link(destination: AppInfo.bugReport) {
                        Label("回報問題", systemImage: "ladybug")
                    }
                    .buttonStyle(.glass)
                    Link(destination: AppInfo.translate) {
                        Label("協助翻譯", systemImage: "globe")
                    }
                    .buttonStyle(.glass)
                }
            }
            .controlSize(.large)
            .padding(.top, 22)

            Spacer(minLength: 16)

            VStack(spacing: 8) {
                HStack(spacing: 14) {
                    Link("隱私權政策", destination: AppInfo.privacy)
                    Link("使用條款", destination: AppInfo.terms)
                    Link("MIT 授權", destination: AppInfo.license)
                }
                .font(.caption)
                Text("DiskLens 是開源軟體，不收集任何資料。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: AppInfo.copyright)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 22)
        }
        .frame(width: 440, height: 470)
        .background(AmbientBackground())
    }
}
