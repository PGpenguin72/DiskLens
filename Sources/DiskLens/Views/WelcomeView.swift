import SwiftUI
import DiskLensCore

/// Shown before the first scan finishes: hero capacity ring, live progress, or the last error.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.scanState {
        case .scanning:
            ScanProgressPanel()
        case .failed(let message):
            Hero {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
            } title: {
                Text("掃描失敗")
            } subtitle: {
                Text(message)
            }
        case .idle, .finished:
            Hero {
                if let volume = model.volume {
                    VStack(spacing: 18) {
                        CapacityGauge(volume: volume, lineWidth: 22)
                            .frame(width: 250, height: 250)
                        CapacityLegend(volume: volume)
                    }
                } else {
                    Image(systemName: "internaldrive").font(.system(size: 64))
                }
            } title: {
                Text("看看空間都跑去哪了")
            } subtitle: {
                Text("掃描整顆磁碟，用環狀圖一眼看出誰最佔空間。檔案只會移到垃圾桶，不會直接刪除。")
            }
        }
    }
}

/// Centered glass card: artwork, title, subtitle and the scan buttons.
private struct Hero<Art: View>: View {
    @ViewBuilder var art: Art
    var title: () -> Text
    var subtitle: () -> Text

    var body: some View {
        VStack(spacing: 26) {
            art
            VStack(spacing: 8) {
                title()
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                subtitle()
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            ScanButtons()
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
        .glassCard(cornerRadius: 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Live scan progress: spinning ring, big item counter, current path.
struct ScanProgressPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 26) {
            ZStack {
                Circle().stroke(.primary.opacity(0.08), lineWidth: 18)
                if let fraction {
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(Theme.accentGradient, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.3), value: fraction)
                }
                SpinningArc()
                VStack(spacing: 4) {
                    Text(model.progress.itemsScanned, format: .number)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("個項目")
                        .foregroundStyle(.secondary)
                    if model.progress.bytesScanned > 0 {
                        Text(ByteFormat.string(model.progress.bytesScanned))
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.used)
                    }
                }
            }
            .frame(width: 250, height: 250)

            VStack(spacing: 8) {
                Text("正在掃描「\(model.scanRootDisplayName)」")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("經過 \(Duration.seconds(model.scanElapsed).formatted(.time(pattern: .minuteSecond)))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(model.progress.currentPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .frame(maxWidth: 440)
                    .glassEffect(.regular, in: .capsule)
            }
            ScanButtons()
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
        .glassCard(cornerRadius: 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Determinate progress when scanning the whole disk (bytes found vs. used space).
    private var fraction: Double? {
        guard model.scanRoot?.path == "/", let volume = model.volume, volume.used > 0,
              model.progress.bytesScanned > 0 else { return nil }
        return min(1, Double(model.progress.bytesScanned) / Double(volume.used))
    }
}

/// Endless comet-like arc that shows the scan is alive.
private struct SpinningArc: View {
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.22)
            .stroke(AngularGradient(colors: [.clear, Color(red: 0.45, green: 0.8, blue: 1.0)], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(80)),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round))
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}
