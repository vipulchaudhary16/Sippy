import AppKit
import SippyCore
import SwiftUI

/// Renders the overlay in each stage to PNG, for checking the art without a live screen.
/// `builtin` ignores the user's Character folder (for docs screenshots).
@MainActor
func renderPreviews(to dir: URL, builtin: Bool = false) {
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var bottle = AppSettings()
    bottle.trackingMode = .bottle
    let shots: [(String, OverlayState.Stage, CharacterPose, String, AppSettings)] = [
        ("1-walk", .arriving, .walking, "", AppSettings()),
        ("2-sip", .arriving, .sipping, "", AppSettings()),
        ("3-ask", .asking, .idle, "Psst! Water break time 💧\n(3 of 8 glasses so far today)", AppSettings()),
        ("4-cheer", .answered, .cheering, "Yay! That's 4 of 8 glasses today 💧", AppSettings()),
        ("5-ask-bottle", .asking, .idle, "Psst! Water break time 💧\n(1.2 of 2.5 L so far today)", bottle),
    ]
    for (name, stage, pose, message, settings) in shots {
        let state = OverlayState()
        state.stage = stage
        state.pose = pose
        state.message = message
        state.sprites = builtin ? SpriteSet() : SpriteSet.load()
        state.options = Amounts(settings).drinkOptions
        let view = ReminderView(state: state, onDrink: { _ in }, onSnooze: {}, snoozeMinutes: { 10 })
            .background(Color(white: 0.85)) // stand-in for the desktop
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }

    // Menu-bar icon, blown up 8x on light and dark bars.
    let icon = AppDelegate.glassIcon()
    let sheet = NSImage(size: NSSize(width: 320, height: 160), flipped: false) { _ in
        for (i, bar) in [NSColor(white: 0.93, alpha: 1), NSColor(white: 0.16, alpha: 1)].enumerated() {
            let frame = NSRect(x: CGFloat(i) * 160, y: 0, width: 160, height: 160)
            bar.setFill()
            frame.fill()
            let tinted = NSImage(size: icon.size, flipped: false) { r in
                icon.draw(in: r)
                (i == 0 ? NSColor.black : NSColor.white).set()
                r.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: frame.insetBy(dx: 8, dy: 8))
        }
        return true
    }
    if let tiff = sheet.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
        try? png.write(to: dir.appendingPathComponent("menubar.png"))
    }
}
