import SwiftUI

/// Shared colors and glass styling.
enum Theme {
    /// Chart palette: one hue per top-level item, shared by the sunburst, legend and table dots.
    static let palette: [Color] = [
        Color(red: 0.25, green: 0.56, blue: 1.00),   // blue
        Color(red: 1.00, green: 0.55, blue: 0.20),   // orange
        Color(red: 0.30, green: 0.85, blue: 0.55),   // green
        Color(red: 0.98, green: 0.36, blue: 0.56),   // pink
        Color(red: 0.66, green: 0.42, blue: 1.00),   // violet
        Color(red: 0.20, green: 0.80, blue: 0.86),   // teal
        Color(red: 1.00, green: 0.80, blue: 0.25),   // yellow
        Color(red: 0.95, green: 0.30, blue: 0.30),   // red
        Color(red: 0.42, green: 0.48, blue: 1.00),   // indigo
        Color(red: 0.55, green: 0.90, blue: 0.80),   // mint
        Color(red: 0.80, green: 0.60, blue: 0.42),   // tan
        Color(red: 0.45, green: 0.75, blue: 1.00),   // sky
    ]

    static func color(_ index: Int) -> Color { palette[index % palette.count] }

    static let used = Color(red: 0.38, green: 0.52, blue: 1.00)
    static let purgeable = Color(red: 0.62, green: 0.45, blue: 1.00)
    static let accentGradient = LinearGradient(colors: [Color(red: 0.36, green: 0.62, blue: 1.0), Color(red: 0.62, green: 0.40, blue: 1.0)],
                                               startPoint: .leading, endPoint: .trailing)
}

/// Soft colored glow behind the content so the glass has something to refract.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        ZStack {
            (dark ? Color(red: 0.05, green: 0.06, blue: 0.11) : Color(red: 0.94, green: 0.95, blue: 0.99))
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.62, 0.42], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: dark ? [
                Color(red: 0.10, green: 0.12, blue: 0.30), Color(red: 0.06, green: 0.07, blue: 0.15), Color(red: 0.22, green: 0.10, blue: 0.34),
                Color(red: 0.05, green: 0.09, blue: 0.20), Color(red: 0.07, green: 0.08, blue: 0.16), Color(red: 0.08, green: 0.06, blue: 0.16),
                Color(red: 0.03, green: 0.16, blue: 0.22), Color(red: 0.06, green: 0.07, blue: 0.14), Color(red: 0.14, green: 0.07, blue: 0.22),
            ] : [
                Color(red: 0.80, green: 0.86, blue: 1.00), Color(red: 0.95, green: 0.95, blue: 1.00), Color(red: 0.92, green: 0.84, blue: 1.00),
                Color(red: 0.90, green: 0.94, blue: 1.00), Color(red: 0.97, green: 0.97, blue: 1.00), Color(red: 0.96, green: 0.92, blue: 1.00),
                Color(red: 0.82, green: 0.95, blue: 0.96), Color(red: 0.95, green: 0.96, blue: 1.00), Color(red: 0.98, green: 0.88, blue: 0.95),
            ])
            .opacity(0.95)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Rounded Liquid Glass panel.
    func glassCard(cornerRadius: CGFloat = 22, tint: Color? = nil) -> some View {
        glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
    }
}

/// Small glass capsule with an icon, value and caption — used for scan statistics.
struct StatChip: View {
    let symbol: String
    let value: String
    let caption: String
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}
