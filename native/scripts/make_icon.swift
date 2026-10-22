// Draws the Sippy app icon (a cute glass of water with a straw) into an .iconset folder.
// Usage: swift scripts/make_icon.swift <output.iconset> [preview.png]
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: x * s, y: y * s, width: w * s, height: h * s)
    }

    // Rounded-square background, macOS style.
    let bg = NSBezierPath(roundedRect: r(0.1, 0.1, 0.8, 0.8), xRadius: 0.18 * s, yRadius: 0.18 * s)
    NSGradient(colors: [color(0.78, 0.93, 1), color(0.45, 0.72, 0.98)])!.draw(in: bg, angle: -90)

    // Glass: a tumbler that narrows toward the bottom.
    let topY: CGFloat = 0.74, botY: CGFloat = 0.2
    let topL: CGFloat = 0.27, topR: CGFloat = 0.73, botL: CGFloat = 0.33, botR: CGFloat = 0.67
    func edge(_ y: CGFloat, left: Bool) -> CGFloat {
        let t = (y - botY) / (topY - botY)
        return left ? botL + (topL - botL) * t : botR + (topR - botR) * t
    }
    let glass = NSBezierPath()
    glass.move(to: p(topL, topY))
    glass.line(to: p(botL, botY + 0.03))
    glass.curve(to: p(botL + 0.04, botY), controlPoint1: p(botL, botY + 0.01), controlPoint2: p(botL + 0.01, botY))
    glass.line(to: p(botR - 0.04, botY))
    glass.curve(to: p(botR, botY + 0.03), controlPoint1: p(botR - 0.01, botY), controlPoint2: p(botR, botY + 0.01))
    glass.line(to: p(topR, topY))
    glass.close()

    // Straw behind the water, leaning out of the glass.
    let straw = NSBezierPath()
    straw.move(to: p(0.5, 0.3))
    straw.line(to: p(0.62, 0.84))
    straw.line(to: p(0.74, 0.86))
    straw.lineWidth = 0.045 * s
    straw.lineCapStyle = .round
    straw.lineJoinStyle = .round
    color(1, 0.55, 0.65).setStroke()
    straw.stroke()

    // Glass body (faint) then water clipped to the glass.
    color(1, 1, 1, 0.45).setFill()
    glass.fill()
    NSGraphicsContext.saveGraphicsState()
    glass.addClip()
    let level: CGFloat = 0.55
    let water = NSBezierPath()
    water.move(to: p(0.2, 0.15))
    water.line(to: p(0.2, level))
    water.curve(to: p(0.5, level), controlPoint1: p(0.3, level + 0.04), controlPoint2: p(0.4, level - 0.04))
    water.curve(to: p(0.8, level), controlPoint1: p(0.6, level + 0.04), controlPoint2: p(0.7, level - 0.04))
    water.line(to: p(0.8, 0.15))
    water.close()
    NSGradient(colors: [color(0.42, 0.78, 1), color(0.16, 0.5, 0.95)])!.draw(in: water, angle: -90)
    // Bubbles
    color(1, 1, 1, 0.6).setFill()
    NSBezierPath(ovalIn: r(0.6, 0.44, 0.03, 0.03)).fill()
    NSBezierPath(ovalIn: r(0.56, 0.49, 0.02, 0.02)).fill()
    NSBezierPath(ovalIn: r(0.39, 0.25, 0.022, 0.022)).fill()
    // Shine down the left side
    let shine = NSBezierPath()
    shine.move(to: p(edge(0.68, left: true) + 0.04, 0.68))
    shine.line(to: p(edge(0.3, left: true) + 0.04, 0.3))
    shine.lineWidth = 0.025 * s
    shine.lineCapStyle = .round
    color(1, 1, 1, 0.55).setStroke()
    shine.stroke()
    NSGraphicsContext.restoreGraphicsState()

    // Glass outline and rim.
    glass.lineWidth = max(1, 0.022 * s)
    glass.lineJoinStyle = .round
    color(0.12, 0.38, 0.75).setStroke()
    glass.stroke()
    let rim = NSBezierPath(ovalIn: r(topL, topY - 0.025, topR - topL, 0.05))
    rim.lineWidth = max(1, 0.018 * s)
    color(1, 1, 1, 0.5).setFill()
    rim.fill()
    rim.stroke()

    // Face on the water.
    let ink = color(0.1, 0.2, 0.4)
    ink.setFill()
    NSBezierPath(ovalIn: r(0.41, 0.37, 0.04, 0.055)).fill()
    NSBezierPath(ovalIn: r(0.55, 0.37, 0.04, 0.055)).fill()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: r(0.425, 0.4, 0.014, 0.014)).fill()
    NSBezierPath(ovalIn: r(0.565, 0.4, 0.014, 0.014)).fill()
    color(1, 0.55, 0.7, 0.7).setFill()
    NSBezierPath(ovalIn: r(0.36, 0.33, 0.055, 0.03)).fill()
    NSBezierPath(ovalIn: r(0.585, 0.33, 0.055, 0.03)).fill()
    let smile = NSBezierPath()
    smile.move(to: p(0.47, 0.34))
    smile.curve(to: p(0.53, 0.34), controlPoint1: p(0.48, 0.3), controlPoint2: p(0.52, 0.3))
    smile.lineWidth = max(1, 0.014 * s)
    smile.lineCapStyle = .round
    ink.setStroke()
    smile.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try draw(base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try draw(base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
if CommandLine.arguments.count > 2 {
    try draw(512).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
