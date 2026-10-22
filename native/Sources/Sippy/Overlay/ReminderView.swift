import SwiftUI

struct ReminderView: View {
    @ObservedObject var state: OverlayState
    let onDrank: () -> Void
    let onSnooze: () -> Void
    let snoozeMinutes: () -> Int

    private var showBubble: Bool { state.stage == .asking || state.stage == .answered }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear

            if showBubble {
                bubble
                    .frame(width: 230)
                    .position(x: 255, y: 115)
                    .transition(.scale(scale: 0.3, anchor: .bottomLeading).combined(with: .opacity))
            }

            CharacterView(pose: state.pose, sprites: state.sprites)
                .frame(width: 210, height: 310)
                .scaleEffect(x: state.facingLeft ? -1 : 1, y: 1)
        }
        .frame(width: 380, height: 500)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: state.stage)
    }

    private var bubble: some View {
        VStack(spacing: 12) {
            Text(state.message)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.15))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if state.stage == .asking {
                VStack(spacing: 8) {
                    Button(action: onDrank) {
                        Label("Yes, I drank!", systemImage: "drop.fill")
                    }
                    .buttonStyle(PillButton(fill: Color(red: 0.2, green: 0.55, blue: 0.95), text: .white))

                    Button(action: onSnooze) {
                        Label("Snooze \(snoozeMinutes()) min", systemImage: "moon.zzz.fill")
                    }
                    .buttonStyle(PillButton(fill: Color(white: 0.92), text: Color(white: 0.25)))
                }
            }
        }
        .padding(16)
        .background(
            SpeechBubble()
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        )
    }
}

struct PillButton: ButtonStyle {
    let fill: Color
    let text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Capsule().fill(fill))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .contentShape(Capsule())
    }
}

/// Rounded rectangle with a tail pointing down-left toward the character's head.
struct SpeechBubble: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: r, cornerRadius: 18)
        p.move(to: CGPoint(x: r.minX + 28, y: r.maxY - 2))
        p.addLine(to: CGPoint(x: r.minX - 14, y: r.maxY + 26))
        p.addLine(to: CGPoint(x: r.minX + 56, y: r.maxY - 2))
        p.closeSubpath()
        return p
    }
}
