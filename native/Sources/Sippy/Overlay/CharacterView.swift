import AppKit
import SwiftUI
import SippyCore

enum CharacterPose: Equatable {
    case walking, idle, sipping, cheering
}

/// Shows the user's sprite frames when they've supplied them, otherwise the built-in drawn character.
struct CharacterView: View {
    let pose: CharacterPose
    let sprites: SpriteSet

    /// Brisk steps, slow gulps, bouncy cheer.
    private var fps: Double {
        switch pose {
        case .walking: return 8
        case .sipping: return 2
        case .cheering: return 3
        case .idle: return 4
        }
    }

    var body: some View {
        if let frames = sprites.frames(for: pose) {
            SpriteView(frames: frames, fps: fps, blinks: pose == .idle)
        } else {
            DrawnCharacter(pose: pose)
        }
    }
}

// MARK: - User sprites

/// Frames loaded from ~/Library/Application Support/Sippy/Character:
/// walk_0.png, walk_1.png… idle_0.png… sip_0.png… cheer_0.png… (any missing set falls back sensibly).
struct SpriteSet {
    var walk: [NSImage] = []
    var idle: [NSImage] = []
    var sip: [NSImage] = []
    var cheer: [NSImage] = []

    var isEmpty: Bool { walk.isEmpty && idle.isEmpty && sip.isEmpty && cheer.isEmpty }

    func frames(for pose: CharacterPose) -> [NSImage]? {
        // When a pose borrows the idle set, use only the eyes-open frame so it doesn't flicker.
        let still = Array(idle.prefix(1))
        let set: [NSImage]
        switch pose {
        case .walking: set = walk.isEmpty ? still : walk
        case .idle: set = idle.isEmpty ? Array(walk.prefix(1)) : idle
        case .sipping: set = sip.isEmpty ? still : sip
        case .cheering: set = cheer.isEmpty ? (idle.isEmpty ? sip : still) : cheer
        }
        if set.isEmpty { return isEmpty ? nil : frames(for: .idle) }
        return set
    }

    static func load(from dir: URL = AppPaths.characterDirectory) -> SpriteSet {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        func frames(_ prefix: String) -> [NSImage] {
            files
                .filter { $0.lastPathComponent.lowercased().hasPrefix(prefix + "_") && $0.pathExtension.lowercased() == "png" }
                .sorted { frameNumber($0) < frameNumber($1) }
                .compactMap { NSImage(contentsOf: $0) }
        }
        return SpriteSet(walk: frames("walk"), idle: frames("idle"), sip: frames("sip"), cheer: frames("cheer"))
    }

    private static func frameNumber(_ url: URL) -> Int {
        Int(url.deletingPathExtension().lastPathComponent.split(separator: "_").last ?? "") ?? 0
    }
}

struct SpriteView: View {
    let frames: [NSImage]
    let fps: Double
    /// Idle: hold the first frame and flash the last one briefly every few seconds (a blink).
    var blinks = false

    private var isPixelArt: Bool {
        (frames.first?.representations.first?.pixelsWide ?? 0) <= 256
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: blinks ? 0.06 : 1 / fps)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let i = blinks
                ? (t.truncatingRemainder(dividingBy: 3.5) < 0.18 ? frames.count - 1 : 0)
                : Int(t * fps) % frames.count
            Image(nsImage: frames[i])
                .resizable()
                // Small frames are pixel art: keep them crisp. Big ones are illustrations: smooth them.
                .interpolation(isPixelArt ? .none : .high)
                .scaledToFit()
        }
    }
}

// MARK: - Built-in character

/// A chibi kid with a big head, blush, and a water bottle. Coordinates are in a 160×230 box.
struct DrawnCharacter: View {
    let pose: CharacterPose

    private let skin = Color(red: 1.0, green: 0.86, blue: 0.74)
    private let hair = Color(red: 0.33, green: 0.22, blue: 0.17)
    private let shirt = Color(red: 0.36, green: 0.72, blue: 0.95)
    private let pants = Color(red: 0.25, green: 0.33, blue: 0.55)

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            figure(t: t)
        }
        .frame(width: 160, height: 230)
    }

    private func figure(t: Double) -> some View {
        let walking = pose == .walking
        let swing = walking ? sin(t * 9) * 24 : 0
        let bob = walking ? abs(sin(t * 9)) * -5 : (pose == .cheering ? abs(sin(t * 7)) * -14 : sin(t * 2) * 1.5)
        let blink = !walking && pose != .sipping && Int(t * 10) % 37 == 0

        return ZStack {
            // Ground shadow stays put while the body bobs.
            Ellipse().fill(.black.opacity(0.15)).frame(width: 80, height: 12).position(x: 80, y: 222)

            ZStack {
                leg(angle: swing).position(x: 66, y: 190)
                leg(angle: -swing).position(x: 94, y: 190)

                // Back arm
                arm(angle: walking ? -swing : (pose == .cheering ? 150 : 10)).position(x: 52, y: 142)

                RoundedRectangle(cornerRadius: 22).fill(shirt).frame(width: 66, height: 64).position(x: 80, y: 160)
                // Little water drop logo on the shirt
                Image(systemName: "drop.fill").font(.system(size: 14)).foregroundStyle(.white.opacity(0.85))
                    .position(x: 80, y: 160)

                head(blink: blink)

                bottleArm(t: t)
            }
            .offset(y: bob)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: pose)
    }

    private func leg(angle: Double) -> some View {
        VStack(spacing: 0) {
            Capsule().fill(pants).frame(width: 16, height: 34)
            Capsule().fill(Color(white: 0.25)).frame(width: 22, height: 10).offset(x: 3, y: -4)
        }
        .rotationEffect(.degrees(angle), anchor: .top)
        .offset(y: 12)
    }

    private func arm(angle: Double) -> some View {
        Capsule().fill(skin).frame(width: 13, height: 40)
            .rotationEffect(.degrees(angle), anchor: .top)
            .offset(y: 16)
    }

    private func head(blink: Bool) -> some View {
        let happyEyes = pose == .sipping || pose == .cheering || blink
        return ZStack {
            Circle().fill(hair).frame(width: 112, height: 108).position(x: 80, y: 66)
            // Ahoge: the one stubborn hair strand
            Capsule().fill(hair).frame(width: 7, height: 26).rotationEffect(.degrees(25)).position(x: 90, y: 10)
            Ellipse().fill(skin).frame(width: 96, height: 86).position(x: 80, y: 80)
            // Bangs
            Ellipse().fill(hair).frame(width: 64, height: 30).position(x: 62, y: 44)
            Ellipse().fill(hair).frame(width: 54, height: 26).position(x: 104, y: 46)

            Group {
                if happyEyes {
                    HappyEye().stroke(Color(white: 0.15), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 14, height: 7).position(x: 64, y: 82)
                    HappyEye().stroke(Color(white: 0.15), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 14, height: 7).position(x: 98, y: 82)
                } else {
                    eye.position(x: 64, y: 82)
                    eye.position(x: 98, y: 82)
                }
            }

            Ellipse().fill(Color.pink.opacity(0.45)).frame(width: 16, height: 9).position(x: 54, y: 98)
            Ellipse().fill(Color.pink.opacity(0.45)).frame(width: 16, height: 9).position(x: 108, y: 98)

            if pose == .cheering {
                Ellipse().fill(Color(red: 0.75, green: 0.25, blue: 0.3)).frame(width: 16, height: 12).position(x: 81, y: 101)
            } else if pose != .sipping {
                Smile().stroke(Color(white: 0.2), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 14, height: 6).position(x: 81, y: 99)
            }
        }
    }

    private var eye: some View {
        ZStack {
            Ellipse().fill(Color(white: 0.12)).frame(width: 12, height: 16)
            Circle().fill(.white).frame(width: 5, height: 5).offset(x: 2, y: -3)
        }
    }

    /// Front arm holding the bottle: at the side while walking, up to the mouth while sipping.
    private func bottleArm(t: Double) -> some View {
        let sipping = pose == .sipping
        let cheering = pose == .cheering
        let walkSwing = pose == .walking ? sin(t * 9) * 18 : 0
        let armAngle = sipping ? -140.0 : (cheering ? -160 : -10 + walkSwing)
        return ZStack {
            Capsule().fill(skin).frame(width: 13, height: 40)
                .rotationEffect(.degrees(armAngle), anchor: .top)
                .offset(y: 16)
                .position(x: 108, y: 142)
            WaterBottle(level: sipping ? 0.45 + 0.1 * sin(t * 3) : 0.7)
                .frame(width: 22, height: 44)
                .rotationEffect(.degrees(sipping ? -105 : (cheering ? 10 : 0)))
                .position(x: sipping ? 104 : (cheering ? 124 : 116), y: sipping ? 94 : (cheering ? 92 : 178))
        }
    }
}

struct WaterBottle: View {
    let level: Double

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.75))
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [Color(red: 0.45, green: 0.8, blue: 1), Color(red: 0.2, green: 0.55, blue: 0.95)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: (h - 8) * level)
                RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.2, green: 0.45, blue: 0.8), lineWidth: 2)
                RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.2, green: 0.45, blue: 0.8))
                    .frame(width: w * 0.55, height: 7).offset(y: -h + 6)
            }
        }
    }
}

struct HappyEye: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height))
        return p
    }
}

struct Smile: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY + r.height))
        return p
    }
}
