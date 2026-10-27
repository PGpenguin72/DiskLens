import SwiftUI
import RingwiseCore

/// Ring gauge of the volume: used, purgeable and free space, with free space in the middle.
struct CapacityGauge: View {
    let volume: VolumeInfo
    var lineWidth: CGFloat = 14
    var showsCaption = true

    var body: some View {
        let total = Double(max(volume.total, 1))
        let used = Double(volume.used - volume.purgeable) / total
        let purgeable = Double(volume.purgeable) / total
        ZStack {
            ZStack {
                Circle().stroke(.primary.opacity(0.08), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: used + purgeable)
                    .stroke(Theme.purgeable.opacity(0.75), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                Circle()
                    .trim(from: 0, to: used)
                    .stroke(AngularGradient(colors: [Color(red: 0.30, green: 0.75, blue: 1.0), Theme.used, Color(red: 0.62, green: 0.40, blue: 1.0)],
                                            center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * used)),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .shadow(color: Theme.used.opacity(0.5), radius: lineWidth * 0.6)
            }
            .rotationEffect(.degrees(-90))   // start at 12 o'clock
            if showsCaption {
                VStack(spacing: 2) {
                    Text(ByteFormat.string(volume.available))
                        .font(.system(size: lineWidth * 2.1, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("可用空間")
                        .font(.system(size: max(10, lineWidth * 0.85)))
                        .foregroundStyle(.secondary)
                }
                .padding(lineWidth * 1.4)
            }
        }
        .padding(lineWidth / 2)
    }
}

/// Used / purgeable / free legend under a gauge.
struct CapacityLegend: View {
    let volume: VolumeInfo
    var axis: Axis = .horizontal

    var body: some View {
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
        layout {
            LegendDot(color: Theme.used, title: "已使用", value: volume.used - volume.purgeable)
            if volume.purgeable > 0 {
                LegendDot(color: Theme.purgeable, title: "可清除", value: volume.purgeable)
                    .help("macOS 可在需要時自動釋放的空間（快取、iCloud 檔案等）。")
            }
            LegendDot(color: .primary.opacity(0.25), title: "可用", value: volume.available)
        }
        .font(.caption)
    }
}

private struct LegendDot: View {
    let color: Color
    let title: LocalizedStringKey
    let value: Int64

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).foregroundStyle(.secondary)
            Text(ByteFormat.string(value)).monospacedDigit().fontWeight(.medium)
        }
    }
}
