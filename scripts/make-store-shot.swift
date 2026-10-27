// Composes an App Store screenshot: gradient background, headline, subtitle and a window capture.
// Usage: swift scripts/make-store-shot.swift <window.png> <out.png> "<headline>" "<subtitle>"
// Output is 2880×1800 (Mac App Store size).
import AppKit

let args = CommandLine.arguments
guard args.count >= 5, let window = NSImage(contentsOfFile: args[1]) else {
    FileHandle.standardError.write("usage: make-store-shot.swift <window.png> <out.png> <headline> <subtitle>\n".data(using: .utf8)!)
    exit(1)
}
let width = 2880, height = 1800
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let canvas = NSRect(x: 0, y: 0, width: width, height: height)

// Deep blue-violet gradient with two soft glows, matching the app's ambient background.
NSGradient(colors: [NSColor(red: 0.07, green: 0.08, blue: 0.20, alpha: 1),
                    NSColor(red: 0.16, green: 0.09, blue: 0.30, alpha: 1)])!.draw(in: canvas, angle: -60)
for (center, color) in [(NSPoint(x: 600, y: 1500), NSColor(red: 0.25, green: 0.45, blue: 1.0, alpha: 0.35)),
                        (NSPoint(x: 2400, y: 300), NSColor(red: 0.62, green: 0.35, blue: 1.0, alpha: 0.30))] {
    NSGradient(colors: [color, color.withAlphaComponent(0)])!
        .draw(fromCenter: center, radius: 0, toCenter: center, radius: 1300, options: [])
}

// Headline and subtitle, centered.
func draw(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? font
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [.font: rounded, .foregroundColor: color, .paragraphStyle: style]
    let rect = NSRect(x: 120, y: y, width: CGFloat(width) - 240, height: size * 1.4)
    (text as NSString).draw(in: rect, withAttributes: attrs)
}
draw(args[3], size: 118, weight: .bold, color: .white, y: 1560)
draw(args[4], size: 54, weight: .medium, color: NSColor(white: 1, alpha: 0.72), y: 1470)

// Window capture (already has its own shadow), scaled to fit below the text.
let maxW: CGFloat = 2500, maxH: CGFloat = 1380
let scale = min(maxW / window.size.width, maxH / window.size.height)
let size = NSSize(width: window.size.width * scale, height: window.size.height * scale)
let origin = NSPoint(x: (CGFloat(width) - size.width) / 2, y: 1430 - size.height)
window.draw(in: NSRect(origin: origin, size: size), from: .zero, operation: .sourceOver, fraction: 1)

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: args[2]))
print("==> \(args[2])")
