import AppKit
import SwiftUI
import SippyCore

/// What the overlay is showing right now; drives `ReminderView`.
final class OverlayState: ObservableObject {
    enum Stage { case arriving, asking, answered, leaving }

    @Published var stage: Stage = .arriving
    @Published var pose: CharacterPose = .walking
    @Published var facingLeft = false
    @Published var message = ""
    @Published var sprites = SpriteSet()
}

/// Floating, transparent, always-on-top panel: the character walks in from the
/// left edge of whichever screen the mouse is on, sips, asks, then walks out.
final class OverlayController {
    private unowned let model: AppModel
    private let state = OverlayState()
    private var panel: NSPanel?
    private var pending: [DispatchWorkItem] = []
    private(set) var isShowing = false

    private let size = NSSize(width: 380, height: 500)
    private let walkInSeconds = 2.6
    private let sipSeconds = 2.2
    private let walkOutSeconds = 2.0

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        guard !isShowing else { return }
        isShowing = true
        cancelPending()

        let screen = currentScreen().visibleFrame
        let start = NSRect(x: screen.minX - size.width, y: screen.minY, width: size.width, height: size.height)
        let target = start.offsetBy(dx: size.width + 24, dy: 0)

        state.sprites = SpriteSet.load()
        state.stage = .arriving
        state.pose = .walking
        state.facingLeft = false
        state.message = ReminderMessages.random(today: model.todayCount, goal: model.settings.dailyGoal)

        let panel = makePanelIfNeeded()
        panel.setFrame(start, display: false)
        panel.orderFrontRegardless()

        let s = model.settings
        model.audio.start(paths: s.musicPaths, volume: s.volume, muted: s.muted)
        model.audio.playEffect(AppPaths.appearSound, volume: s.volume, muted: s.muted)

        animate(panel, to: target, seconds: walkInSeconds) { [weak self] in
            guard let self else { return }
            self.state.pose = .sipping
            self.after(self.sipSeconds) {
                self.state.pose = .idle
                self.state.stage = .asking
                // Nobody home? Snooze quietly instead of waiting forever.
                self.after(Double(self.model.settings.autoSnoozeMinutes * 60)) {
                    if self.state.stage == .asking { self.answer(drank: false) }
                }
            }
        }
    }

    func answer(drank: Bool) {
        guard isShowing, state.stage == .asking || state.stage == .arriving else { return }
        cancelPending()
        model.audio.stop()
        state.stage = .answered
        if drank {
            model.drank()
            let s = model.settings
            model.audio.playEffect(AppPaths.cheerSound, volume: s.volume, muted: s.muted)
            let goal = model.settings.dailyGoal
            let today = model.todayCount
            state.pose = .cheering
            state.message = today >= goal
                ? "Yay! \(today) of \(goal) — goal smashed! 🎉"
                : "Yay! That's \(today) of \(goal) today 💧"
        } else {
            model.snooze()
            state.pose = .idle
            state.message = "Okay! I'll be back in \(model.settings.snoozeMinutes) min ⏰"
        }
        after(1.8) { [weak self] in self?.leave() }
    }

    private func leave() {
        guard let panel else { return }
        state.stage = .leaving
        state.facingLeft = true
        state.pose = .walking
        let screen = panel.screen?.visibleFrame ?? currentScreen().visibleFrame
        let offscreen = NSRect(x: screen.minX - size.width, y: panel.frame.minY, width: size.width, height: size.height)
        animate(panel, to: offscreen, seconds: walkOutSeconds) { [weak self] in
            panel.orderOut(nil)
            self?.isShowing = false
        }
    }

    // MARK: - Helpers

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        // Show on every Space and over full-screen apps.
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false
        p.contentView = ClickThroughHostingView(rootView: ReminderView(
            state: state,
            onDrank: { [weak self] in self?.answer(drank: true) },
            onSnooze: { [weak self] in self?.answer(drank: false) },
            snoozeMinutes: { [weak self] in self?.model.settings.snoozeMinutes ?? 10 }
        ))
        panel = p
        return p
    }

    private func animate(_ panel: NSPanel, to frame: NSRect, seconds: Double, completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = seconds
            ctx.timingFunction = CAMediaTimingFunction(name: .linear)
            panel.animator().setFrame(frame, display: true)
        }, completionHandler: completion)
    }

    private func after(_ seconds: Double, _ work: @escaping () -> Void) {
        let item = DispatchWorkItem(block: work)
        pending.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func cancelPending() {
        pending.forEach { $0.cancel() }
        pending.removeAll()
    }

    private func currentScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

/// Lets a click on the buttons work immediately, without first focusing the panel.
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

enum ReminderMessages {
    static let lines = [
        "Psst! Water break time 💧",
        "Hey you! Grab a glass of water with me 🥤",
        "Hydration check! When did you last sip?",
        "Your brain is ~75% water. Top it up! 🧠",
        "Sip sip hooray! Time for water 🎉",
        "Plants need water. So do you 🌱",
        "Glug glug? Glug glug. 💦",
    ]

    static func random(today: Int, goal: Int) -> String {
        let line = lines.randomElement()!
        return today == 0 ? line : "\(line)\n(\(today) of \(goal) so far today)"
    }
}
