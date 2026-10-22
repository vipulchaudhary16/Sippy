import AppKit
import SwiftUI

/// Renders the overlay in each stage to PNG, for checking the art without a live screen.
@MainActor
func renderPreviews(to dir: URL) {
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let shots: [(String, OverlayState.Stage, CharacterPose, String)] = [
        ("1-walk", .arriving, .walking, ""),
        ("2-sip", .arriving, .sipping, ""),
        ("3-ask", .asking, .idle, "Psst! Water break time 💧\n(3 of 8 so far today)"),
        ("4-cheer", .answered, .cheering, "Yay! That's 4 of 8 today 💧"),
    ]
    for (name, stage, pose, message) in shots {
        let state = OverlayState()
        state.stage = stage
        state.pose = pose
        state.message = message
        state.sprites = SpriteSet.load()
        let view = ReminderView(state: state, onDrank: {}, onSnooze: {}, snoozeMinutes: { 10 })
            .background(Color(white: 0.85)) // stand-in for the desktop
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }
}
