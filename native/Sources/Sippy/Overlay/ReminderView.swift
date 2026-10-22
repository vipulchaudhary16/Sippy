import SwiftUI
import SippyCore

struct ReminderView: View {
    @ObservedObject var state: OverlayState
    let onDrink: (Int) -> Void
    let onSnooze: () -> Void
    let snoozeMinutes: () -> Int

    private let drinkBlue = Color(red: 0.2, green: 0.55, blue: 0.95)

    private var showBubble: Bool { state.stage == .asking || state.stage == .answered }

    var body: some View {
        ZStack(alignment: state.fromRight ? .bottomTrailing : .bottomLeading) {
            Color.clear

            if showBubble {
                bubble
                    .frame(width: 230)
                    .position(x: state.fromRight ? 380 - 255 : 255, y: 125)
                    .transition(.scale(scale: 0.3, anchor: state.fromRight ? .bottomTrailing : .bottomLeading)
                        .combined(with: .opacity))
            }

            CharacterView(pose: state.pose, sprites: state.sprites)
                .frame(width: 210, height: 310)
                .scaleEffect(x: state.facingLeft ? -1 : 1, y: 1)
        }
        .frame(width: 380, height: 540)
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
                    if state.options.count == 1, let only = state.options.first {
                        Button { onDrink(only.ml) } label: { Label(only.label, systemImage: "drop.fill") }
                            .buttonStyle(PillButton(fill: drinkBlue, text: .white))
                    } else {
                        // Bottle mode: how much did you sip?
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            ForEach(state.options) { option in
                                Button(option.label) { onDrink(option.ml) }
                                    .buttonStyle(PillButton(fill: drinkBlue, text: .white))
                            }
                        }
                    }

                    Button(action: onSnooze) {
                        Label("Snooze \(snoozeMinutes()) min", systemImage: "moon.zzz.fill")
                    }
                    .buttonStyle(PillButton(fill: Color(white: 0.92), text: Color(white: 0.25)))
                }
            }
        }
        .padding(16)
        .background(
            SpeechBubble(tailOnRight: state.fromRight)
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

/// Rounded rectangle with a tail pointing down toward the character's head
/// (down-left normally, down-right when the character stands to the bubble's right).
struct SpeechBubble: Shape {
    var tailOnRight = false

    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: r, cornerRadius: 18)
        if tailOnRight {
            p.move(to: CGPoint(x: r.maxX - 28, y: r.maxY - 2))
            p.addLine(to: CGPoint(x: r.maxX + 14, y: r.maxY + 26))
            p.addLine(to: CGPoint(x: r.maxX - 56, y: r.maxY - 2))
        } else {
            p.move(to: CGPoint(x: r.minX + 28, y: r.maxY - 2))
            p.addLine(to: CGPoint(x: r.minX - 14, y: r.maxY + 26))
            p.addLine(to: CGPoint(x: r.minX + 56, y: r.maxY - 2))
        }
        p.closeSubpath()
        return p
    }
}
