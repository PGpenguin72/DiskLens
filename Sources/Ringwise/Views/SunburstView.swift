import SwiftUI
import RingwiseCore

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
    /// Arcs thinner than this (radians) are not drawn.
    static let minAngle = 0.012
    /// `minAngle` as a fraction of the center folder's size.
    static var minFraction: Double { minAngle / (2 * .pi) }

    static func segments(tree: FileTree, center: NodeID, maxDepth: Int = 3,
                         minAngle: Double = SunburstLayout.minAngle) -> [SunburstSegment] {
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

/// Sunburst ring chart of the current folder. Hover to inspect, click a folder to open it,
/// click a file to select it, click the center to go up.
struct SunburstView: View {
    @Environment(AppModel.self) private var model
    @State private var segments: [SunburstSegment] = []
    private let rings = 3

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let hole = side * 0.2
            let ringWidth = (side / 2 - hole - 2) / CGFloat(rings)
            ZStack {
                ForEach(segments) { seg in
                    let inner = hole + 4 + CGFloat(seg.depth - 1) * ringWidth
                    arc(center: center, inner: inner, outer: inner + ringWidth - 3,
                        start: seg.start, end: seg.end)
                        .fill(fill(for: seg))
                }
                CenterLabel(focus: model.highlighted ?? model.currentDir)
                    .frame(width: hole * 2 - 8, height: hole * 2 - 8)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .position(center)
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): model.highlighted = hit(p, center: center, hole: hole, ringWidth: ringWidth)?.id
                case .ended: model.highlighted = nil
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
        .aspectRatio(1, contentMode: .fit)
        .onAppear(perform: rebuild)
        .onChange(of: model.currentDir) { rebuild() }
        .onChange(of: model.revision) { rebuild() }
        .animation(.easeOut(duration: 0.15), value: model.highlighted)
    }

    private func rebuild() {
        guard let tree = model.tree, let dir = model.currentDir else { segments = []; return }
        segments = SunburstLayout.segments(tree: tree, center: dir, maxDepth: rings)
    }

    private func fill(for seg: SunburstSegment) -> some ShapeStyle {
        let base = Theme.color(seg.colorIndex)
        let c = seg.isDirectory ? base : base.mix(with: .gray, by: 0.5)
        let fade = 1.0 - Double(seg.depth - 1) * 0.2
        let lit = model.highlighted.map { isAncestor($0, of: seg.id) } ?? true
        return c.opacity(fade * (lit ? 1 : 0.28))
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
        guard d >= hole + 4 else { return nil }
        let depth = Int((d - hole - 4) / ringWidth) + 1
        guard depth <= rings else { return nil }
        var angle = atan2(dx, -dy)          // 0 at 12 o'clock, clockwise
        if angle < 0 { angle += 2 * .pi }
        return segments.first { $0.depth == depth && angle >= $0.start && angle < $0.end }
    }

    private func arc(center: CGPoint, inner: CGFloat, outer: CGFloat, start: Double, end: Double) -> Path {
        // Small angular gap between neighbours; Path angles start at 3 o'clock.
        let gap = min(0.006, (end - start) / 4)
        let a0 = Angle(radians: start + gap - .pi / 2), a1 = Angle(radians: end - gap - .pi / 2)
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
            VStack(spacing: 3) {
                Text(tree.displayName(id, volumeName: model.volume?.name))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(ByteFormat.string(tree.size(id)))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let dir = model.currentDir, id != dir, tree.size(dir) > 0 {
                    Text(Double(tree.size(id)) / Double(tree.size(dir)), format: .percent.precision(.fractionLength(1)))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                } else if model.canGoUp {
                    Label("回上層", systemImage: "arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(10)
        }
    }
}

/// Top items of the current folder with their chart colors. Hover highlights, click opens.
struct SunburstLegend: View {
    @Environment(AppModel.self) private var model
    var limit = 7

    var body: some View {
        if let tree = model.tree, let dir = model.currentDir {
            let _ = model.revision
            let total = max(1, Double(tree.size(dir)))
            VStack(spacing: 2) {
                ForEach(Array(tree.children(dir).prefix(limit)), id: \.self) { id in
                    let fraction = Double(tree.size(id)) / total
                    Button {
                        if tree.isDirectory(id) { model.open(id) } else { model.selection = [id] }
                    } label: {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.color(model.chartColorIndex[id] ?? 0))
                                .frame(width: 10, height: 10)
                            Text(tree.displayName(id, volumeName: model.volume?.name))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 6)
                            Text(fraction, format: .percent.precision(.fractionLength(fraction < 0.1 ? 1 : 0)))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                            Text(ByteFormat.string(tree.size(id)))
                                .fontWeight(.medium)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .font(.callout)
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(model.highlighted == id ? AnyShapeStyle(.primary.opacity(0.08)) : AnyShapeStyle(.clear),
                                    in: .rect(cornerRadius: 8))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        if inside { model.highlighted = id } else if model.highlighted == id { model.highlighted = nil }
                    }
                }
            }
        }
    }
}
