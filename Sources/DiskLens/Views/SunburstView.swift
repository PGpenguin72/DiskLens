import SwiftUI
import DiskLensCore

/// One arc of the sunburst: a node drawn at `depth` (1 = direct child of the center folder).
struct SunburstSegment: Identifiable {
    let id: NodeID
    let depth: Int
    let start: Double      // radians, 0 = 12 o'clock, clockwise
    let end: Double
    let colorIndex: Int    // index of the top-level ancestor, drives the hue
    let isDirectory: Bool
}

/// Builds sunburst segments for `center`, `maxDepth` rings deep, dropping arcs thinner than `minAngle`.
enum SunburstLayout {
    static func segments(tree: FileTree, center: NodeID, maxDepth: Int = 3,
                         minAngle: Double = 0.012) -> [SunburstSegment] {
        let total = Double(tree.size(center))
        guard total > 0 else { return [] }
        var out: [SunburstSegment] = []
        func walk(_ node: NodeID, depth: Int, start: Double, colorIndex: Int?) {
            var angle = start
            for (i, child) in tree.children(node).enumerated() {
                let sweep = Double(tree.size(child)) / total * 2 * .pi
                // Children are sorted by size, so the rest are thinner still.
                if sweep < minAngle { break }
                let color = colorIndex ?? i
                out.append(SunburstSegment(id: child, depth: depth, start: angle, end: angle + sweep,
                                           colorIndex: color, isDirectory: tree.isDirectory(child)))
                if depth < maxDepth && tree.isDirectory(child) {
                    walk(child, depth: depth + 1, start: angle, colorIndex: color)
                }
                angle += sweep
            }
        }
        walk(center, depth: 1, start: 0, colorIndex: nil)
        return out
    }
}

/// DaisyDisk-style ring chart of the current folder. Hover to inspect, click a folder to open it,
/// click a file to select it, click the center to go up.
struct SunburstView: View {
    @Environment(AppModel.self) private var model
    @State private var segments: [SunburstSegment] = []
    @State private var hovered: NodeID?

    private static let palette: [Color] = [.blue, .orange, .green, .pink, .purple, .teal, .yellow, .red, .indigo, .mint, .brown, .cyan]
    private let rings = 3

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let hole = side * 0.17
            let ringWidth = (side / 2 - hole - 4) / CGFloat(rings)
            ZStack {
                ForEach(segments) { seg in
                    let inner = hole + CGFloat(seg.depth - 1) * ringWidth
                    arc(center: center, inner: inner + 1, outer: inner + ringWidth - 1,
                        start: seg.start, end: seg.end)
                        .fill(color(for: seg))
                }
                CenterLabel(focus: hovered ?? model.currentDir)
                    .frame(width: hole * 1.8)
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): hovered = hit(p, center: center, hole: hole, ringWidth: ringWidth)?.id
                case .ended: hovered = nil
                }
            }
            .gesture(SpatialTapGesture().onEnded { tap in
                let d = hypot(tap.location.x - center.x, tap.location.y - center.y)
                if d < hole {
                    model.goUp()
                } else if let seg = hit(tap.location, center: center, hole: hole, ringWidth: ringWidth) {
                    if seg.isDirectory { model.open(seg.id) } else { model.selection = [seg.id] }
                }
            })
        }
        .padding(12)
        .onAppear(perform: rebuild)
        .onChange(of: model.currentDir) { rebuild() }
        .onChange(of: model.revision) { rebuild() }
        .help("點選資料夾進入，點中心回上一層")
    }

    private func rebuild() {
        hovered = nil
        guard let tree = model.tree, let dir = model.currentDir else { segments = []; return }
        segments = SunburstLayout.segments(tree: tree, center: dir, maxDepth: rings)
    }

    private func color(for seg: SunburstSegment) -> Color {
        let base = Self.palette[seg.colorIndex % Self.palette.count]
        let fade = 1.0 - Double(seg.depth - 1) * 0.22
        let c = seg.isDirectory ? base : base.mix(with: .gray, by: 0.55)
        let highlighted = hovered == nil || hovered == seg.id || isAncestor(hovered!, of: seg.id)
        return c.opacity(fade * (highlighted ? 1 : 0.35))
    }

    /// True when `a` is `b` or one of `b`'s ancestors (keeps a hovered folder's sub-rings lit).
    private func isAncestor(_ a: NodeID, of b: NodeID) -> Bool {
        guard let tree = model.tree else { return false }
        var cur: NodeID? = b
        while let c = cur, c != model.currentDir {
            if c == a { return true }
            cur = tree.parent(c)
        }
        return false
    }

    private func hit(_ p: CGPoint, center: CGPoint, hole: CGFloat, ringWidth: CGFloat) -> SunburstSegment? {
        let dx = p.x - center.x, dy = p.y - center.y
        let d = hypot(dx, dy)
        guard d >= hole else { return nil }
        let depth = Int((d - hole) / ringWidth) + 1
        guard depth <= rings else { return nil }
        var angle = atan2(dx, -dy)          // 0 at 12 o'clock, clockwise
        if angle < 0 { angle += 2 * .pi }
        return segments.first { $0.depth == depth && angle >= $0.start && angle < $0.end }
    }

    private func arc(center: CGPoint, inner: CGFloat, outer: CGFloat, start: Double, end: Double) -> Path {
        // Path angles start at 3 o'clock; shift so 0 means 12 o'clock.
        let a0 = Angle(radians: start - .pi / 2), a1 = Angle(radians: end - .pi / 2)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: a0, endAngle: a1, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: a1, endAngle: a0, clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// Name and size of the hovered segment (or the current folder) in the middle of the ring.
private struct CenterLabel: View {
    @Environment(AppModel.self) private var model
    let focus: NodeID?

    var body: some View {
        if let tree = model.tree, let id = focus {
            let _ = model.revision
            VStack(spacing: 2) {
                Text(tree.displayName(id, volumeName: model.volume?.name))
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(ByteFormat.string(tree.size(id)))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                if let dir = model.currentDir, id != dir, tree.size(dir) > 0 {
                    Text(Double(tree.size(id)) / Double(tree.size(dir)), format: .percent.precision(.fractionLength(1)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
