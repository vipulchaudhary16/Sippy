// Draws the Sippy app icon (a smiling water drop) into an .iconset folder.
// Usage: swift scripts/make_icon.swift <output.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: x * s, y: y * s, width: w * s, height: h * s)
    }

    // Rounded-square background, macOS style.
    let bg = NSBezierPath(roundedRect: r(0.1, 0.1, 0.8, 0.8), xRadius: 0.18 * s, yRadius: 0.18 * s)
    NSGradient(colors: [NSColor(calibratedRed: 0.62, green: 0.88, blue: 1, alpha: 1),
                        NSColor(calibratedRed: 0.36, green: 0.66, blue: 0.98, alpha: 1)])!
        .draw(in: bg, angle: -90)

    // The drop.
    let drop = NSBezierPath()
    drop.move(to: NSPoint(x: 0.5 * s, y: 0.8 * s))
    drop.curve(to: NSPoint(x: 0.27 * s, y: 0.4 * s), controlPoint1: NSPoint(x: 0.42 * s, y: 0.66 * s),
               controlPoint2: NSPoint(x: 0.27 * s, y: 0.55 * s))
    drop.curve(to: NSPoint(x: 0.73 * s, y: 0.4 * s), controlPoint1: NSPoint(x: 0.27 * s, y: 0.12 * s),
               controlPoint2: NSPoint(x: 0.73 * s, y: 0.12 * s))
    drop.curve(to: NSPoint(x: 0.5 * s, y: 0.8 * s), controlPoint1: NSPoint(x: 0.73 * s, y: 0.55 * s),
               controlPoint2: NSPoint(x: 0.58 * s, y: 0.66 * s))
    NSColor.white.setFill()
    drop.fill()

    // Face.
    let ink = NSColor(calibratedWhite: 0.15, alpha: 1)
    ink.setFill()
    NSBezierPath(ovalIn: r(0.405, 0.37, 0.045, 0.06)).fill()
    NSBezierPath(ovalIn: r(0.55, 0.37, 0.045, 0.06)).fill()
    NSColor.systemPink.withAlphaComponent(0.45).setFill()
    NSBezierPath(ovalIn: r(0.35, 0.31, 0.06, 0.035)).fill()
    NSBezierPath(ovalIn: r(0.59, 0.31, 0.06, 0.035)).fill()
    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: 0.46 * s, y: 0.33 * s))
    smile.curve(to: NSPoint(x: 0.54 * s, y: 0.33 * s), controlPoint1: NSPoint(x: 0.47 * s, y: 0.28 * s),
                controlPoint2: NSPoint(x: 0.53 * s, y: 0.28 * s))
    smile.lineWidth = max(1, 0.012 * s)
    smile.lineCapStyle = .round
    ink.setStroke()
    smile.stroke()

    // Shine.
    NSColor(calibratedRed: 0.62, green: 0.85, blue: 1, alpha: 0.9).setFill()
    NSBezierPath(ovalIn: r(0.33, 0.45, 0.05, 0.1)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try draw(base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try draw(base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
