// Renders a simple Ringwise app icon into an .iconset folder.
// Usage: swift scripts/make-icon.swift <output.iconset>
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Ringwise.iconset")
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels)
    let inset = s * 0.09
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let shape = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.55, blue: 1.0, alpha: 1),
               ending: NSColor(calibratedRed: 0.10, green: 0.25, blue: 0.70, alpha: 1))!.draw(in: shape, angle: -90)

    // Concentric "disk usage" rings.
    let center = NSPoint(x: s / 2, y: s / 2)
    let ring: (CGFloat, CGFloat, CGFloat, NSColor) -> Void = { radius, start, end, color in
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
        path.lineWidth = s * 0.075
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }
    ring(s * 0.28, 360, 0, NSColor.white.withAlphaComponent(0.18))
    ring(s * 0.28, 90, 90 - 290, NSColor.white)
    ring(s * 0.17, 360, 0, NSColor.white.withAlphaComponent(0.18))
    ring(s * 0.17, 90, 90 - 160, NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.30, alpha: 1))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: output.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: output.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
