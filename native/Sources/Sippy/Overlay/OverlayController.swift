import AppKit
import SwiftUI
import SippyCore

/// What the overlay is showing right now; drives `ReminderView`.
final class OverlayState: ObservableObject {
    enum Stage { case arriving, asking, answered, leaving }

    @Published var stage: Stage = .arriving
    @Published var pose: CharacterPose = .walking
    @Published var facingLeft = false
    /// Character stands at the panel's right edge with the bubble to its left.
    @Published var fromRight = false
    @Published var message = ""
    @Published var sprites = SpriteSet()
    @Published var options: [DrinkOption] = []
    /// Set while knocking for a calendar event instead of a water reminder.
    @Published var event: EventPrompt?
}

/// What the bubble offers for a calendar knock.
struct EventPrompt: Equatable {
    let joinURL: URL?
}

/// Floating, transparent, always-on-top panel: the character walks in from the left or
/// right edge, along the bottom or top, of whichever screen the mouse is on, sips, asks,
/// then walks back out.
/// Frames are drawn facing right, so coming from the right they're mirrored to face inward.
final class OverlayController {
    private unowned let model: AppModel
    private let state = OverlayState()
    private var panel: NSPanel?
    private var pending: [DispatchWorkItem] = []
    private(set) var isShowing = false

    private let size = NSSize(width: 380, height: 540)
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

        let fromRight = model.settings.entrySide == .right
        let screen = currentScreen().visibleFrame
        // visibleFrame already excludes the menu bar and Dock.
        let y = model.settings.verticalPosition == .top ? screen.maxY - size.height : screen.minY
        let start = NSRect(x: offscreenX(in: screen, fromRight: fromRight), y: y,
                           width: size.width, height: size.height)
        let target = NSRect(x: fromRight ? screen.maxX - size.width - 24 : screen.minX + 24, y: y,
                            width: size.width, height: size.height)

        state.sprites = SpriteSet.load()
        state.stage = .arriving
        state.pose = .walking
        state.fromRight = fromRight
        state.facingLeft = fromRight
        state.options = model.amounts.drinkOptions
        state.event = nil
        state.message = ReminderMessages.random(today: model.todayML == 0 ? nil : model.amounts.progress(model.todayML))

        let panel = makePanelIfNeeded()
        panel.setFrame(start, display: false)
        panel.alphaValue = 1
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
                    if self.state.stage == .asking { self.answer(ml: nil) }
                }
            }
        }
    }

    /// True while the character is on screen waiting for (or about to ask for) a water answer.
    var isAwaitingAnswer: Bool {
        isShowing && state.event == nil && (state.stage == .asking || state.stage == .arriving)
    }

    /// Walks in and knocks before calendar events. Returns false if the character is busy.
    @discardableResult
    func showEvent(_ events: [UpcomingEvent]) -> Bool {
        guard !isShowing, let first = events.first else { return false }
        isShowing = true
        cancelPending()

        let fromRight = model.settings.entrySide == .right
        let screen = currentScreen().visibleFrame
        let y = model.settings.verticalPosition == .top ? screen.maxY - size.height : screen.minY
        let start = NSRect(x: offscreenX(in: screen, fromRight: fromRight), y: y, width: size.width, height: size.height)
        let target = NSRect(x: fromRight ? screen.maxX - size.width - 24 : screen.minX + 24, y: y,
                            width: size.width, height: size.height)

        state.sprites = SpriteSet.load()
        state.stage = .arriving
        state.pose = .walking
        state.fromRight = fromRight
        state.facingLeft = fromRight
        state.event = EventPrompt(joinURL: first.meetingLink)
        state.message = EventText.headline(events, now: Date())

        let panel = makePanelIfNeeded()
        panel.setFrame(start, display: false)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        animate(panel, to: target, seconds: walkInSeconds) { [weak self] in
            guard let self else { return }
            let s = self.model.settings
            self.state.pose = .knocking
            self.state.stage = .asking
            self.state.message = EventText.headline(events, now: Date())
            self.model.audio.playKnock(volume: s.volume, muted: s.muted)
            self.after(2.4) { if self.state.stage == .asking { self.state.pose = .idle } }
            // Leave on their own after a while if nobody answers.
            self.after(Double(s.autoSnoozeMinutes * 60)) {
                if self.state.stage == .asking { self.answerEvent(join: false) }
            }
        }
        return true
    }

    func answerEvent(join: Bool) {
        guard isShowing, let prompt = state.event, state.stage == .asking || state.stage == .arriving else { return }
        cancelPending()
        state.stage = .answered
        state.pose = .idle
        if join, let url = prompt.joinURL {
            NSWorkspace.shared.open(url)
            state.message = "Joining… have a good one! 👋"
        } else {
            state.message = "Have a good one! 👋"
        }
        after(1.4) { [weak self] in self?.leave() }
    }

    /// `ml` is how much they drank; nil means snooze.
    func answer(ml: Int?) {
        guard isAwaitingAnswer else { return }
        cancelPending()
        model.audio.stop()
        state.stage = .answered
        if let ml {
            model.drank(ml: ml)
            let s = model.settings
            model.audio.playEffect(AppPaths.cheerSound, volume: s.volume, muted: s.muted)
            state.pose = .cheering
            state.message = cheerMessage()
        } else {
            model.snooze()
            state.pose = .idle
            state.message = "Okay! I'll be back in \(model.settings.snoozeMinutes) min ⏰"
        }
        after(1.8) { [weak self] in self?.leave() }
    }

    /// A drink logged from Spotlight, a link or the menu: pop up in the middle of the screen,
    /// cheer with the "yay" sound, then fade away. Returns false if the character is busy.
    @discardableResult
    func celebrate() -> Bool {
        guard !isShowing else { return false }
        isShowing = true
        cancelPending()

        let screen = currentScreen().visibleFrame
        let frame = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2,
                           width: size.width, height: size.height)
        state.sprites = SpriteSet.load()
        state.fromRight = false
        state.facingLeft = false
        state.pose = .cheering
        state.message = cheerMessage()
        state.stage = .answered
        state.event = nil

        let panel = makePanelIfNeeded()
        panel.setFrame(frame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1
        }

        let s = model.settings
        model.audio.playEffect(AppPaths.cheerSound, volume: s.volume, muted: s.muted)

        after(2.6) { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                panel.alphaValue = 1
                self?.isShowing = false
            })
        }
        return true
    }

    private func cheerMessage() -> String {
        let progress = model.amounts.progress(model.todayML)
        return model.todayML >= model.settings.goalML
            ? "Yay! \(progress) — goal smashed! 🎉"
            : "Yay! That's \(progress) today 💧"
    }

    private func leave() {
        guard let panel else { return }
        state.stage = .leaving
        // Turn around and head back to the edge they came from.
        state.facingLeft = !state.fromRight
        state.pose = .walking
        let screen = panel.screen?.visibleFrame ?? currentScreen().visibleFrame
        let offscreen = NSRect(x: offscreenX(in: screen, fromRight: state.fromRight), y: panel.frame.minY,
                               width: size.width, height: size.height)
        animate(panel, to: offscreen, seconds: walkOutSeconds) { [weak self] in
            panel.orderOut(nil)
            self?.isShowing = false
        }
    }

    // MARK: - Helpers

    private func offscreenX(in screen: NSRect, fromRight: Bool) -> CGFloat {
        fromRight ? screen.maxX : screen.minX - size.width
    }

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
            onDrink: { [weak self] ml in self?.answer(ml: ml) },
            onSnooze: { [weak self] in self?.answer(ml: nil) },
            snoozeMinutes: { [weak self] in self?.model.settings.snoozeMinutes ?? 10 },
            onEvent: { [weak self] join in self?.answerEvent(join: join) }
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

    /// `today` is the progress so far ("3 of 8 glasses"), or nil before the first drink.
    static func random(today: String?) -> String {
        let line = lines.randomElement()!
        return today.map { "\(line)\n(\($0) so far today)" } ?? line
    }
}
