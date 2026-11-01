import AppKit
import AVFoundation
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

    // Motion read every frame by `AliveCharacter`; plain properties so they don't re-render SwiftUI.
    /// True while falling or bouncing, so the body stretches.
    var airborne = false
    /// When the character last hit the ground, and how hard (0…1): drives the squash.
    var impactAt: Date?
    var impactStrength: CGFloat = 0
    /// When the character last hopped (on a cheer, or when the cursor touches it).
    var hopAt: Date?
    /// Where the cursor is, from -1 (far left) to 1 (far right) of the character, smoothed.
    var lookX: CGFloat = 0
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
    private var fallTimer: Timer?
    private var cursorTimer: Timer?
    private var cursorWasOnCharacter = false

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
        let target = NSRect(x: stopX(in: screen, fromRight: fromRight), y: y,
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
        model.audio.play(.appear, settings: s)
        followCursor()

        enter(panel, to: target, in: screen) { [weak self] in
            guard let self else { return }
            self.model.audio.stopEffect()
            self.state.pose = .sipping
            self.clipSeconds(.sipping, atLeast: self.sipSeconds) { seconds in
                self.after(seconds) {
                    self.state.pose = .idle
                    self.state.stage = .asking
                    // Nobody home? Snooze quietly instead of waiting forever.
                    self.after(Double(self.model.settings.autoSnoozeMinutes * 60)) {
                        if self.state.stage == .asking { self.answer(ml: nil) }
                    }
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
        let target = NSRect(x: stopX(in: screen, fromRight: fromRight), y: y,
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
        followCursor()

        enter(panel, to: target, in: screen) { [weak self] in
            guard let self else { return }
            let s = self.model.settings
            self.state.pose = .knocking
            self.state.stage = .asking
            self.state.message = EventText.headline(events, now: Date())
            self.model.audio.play(.knock, settings: s)
            self.after(2.4) {
                self.model.audio.stopEffect()
                if self.state.stage == .asking { self.state.pose = .idle }
            }
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
        model.audio.stopEffect()
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
            model.audio.play(.cheer, settings: s)
            state.pose = .cheering
            state.hopAt = Date()
            state.message = cheerMessage()
            // Happy: carry on across the screen and out the far side.
            clipSeconds(.cheering, atLeast: 1.8) { [weak self] seconds in
                self?.after(seconds) { self?.leave(onward: true) }
            }
        } else {
            model.snooze()
            model.audio.play(.sad, settings: model.settings)
            // Disappointed: a sad moment, then back the way they came.
            state.pose = .sad
            state.message = "Okay… I'll be back in \(model.settings.snoozeMinutes) min ⏰"
            clipSeconds(.sad, atLeast: 2.2) { [weak self] seconds in
                self?.after(seconds) { self?.leave() }
            }
        }
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
        state.hopAt = Date()

        let panel = makePanelIfNeeded()
        panel.setFrame(frame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1
        }

        let s = model.settings
        model.audio.play(.cheer, settings: s)

        after(2.6) { [weak self] in
            self?.model.audio.stopEffect()
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                panel.alphaValue = 1
                self?.stopMotion()
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

    /// Walks off screen: `onward` keeps going the way they were heading and out the far side;
    /// otherwise they turn around and go back to the edge they came from.
    private func leave(onward: Bool = false) {
        guard let panel else { return }
        state.stage = .leaving
        let exitRight = onward ? !state.fromRight : state.fromRight
        model.audio.stopEffect()
        if onward { model.audio.play(.walkOut, settings: model.settings) }
        state.facingLeft = !exitRight
        state.pose = .walking
        let screen = panel.screen?.visibleFrame ?? currentScreen().visibleFrame
        let offscreen = NSRect(x: offscreenX(in: screen, fromRight: exitRight), y: panel.frame.minY,
                               width: size.width, height: size.height)
        // Same brisk pace whether it's a few steps back or the whole width of the screen.
        let seconds = max(walkOutSeconds, Double(abs(offscreen.minX - panel.frame.minX)) / 320)
        animate(panel, to: offscreen, seconds: seconds) { [weak self] in
            self?.model.audio.stopEffect()
            panel.orderOut(nil)
            self?.stopMotion()
            self?.isShowing = false
        }
    }

    // MARK: - Entrances

    /// Walks in from the side, or drops in from above and bounces, per the entrance setting.
    private func enter(_ panel: NSPanel, to target: NSRect, in screen: NSRect, then arrived: @escaping () -> Void) {
        let style: EntranceStyle = {
            // Along the top there's nothing to fall from, so it always walks.
            guard model.settings.verticalPosition == .bottom else { return .walk }
            switch model.settings.entranceStyle {
            case .surprise: return Bool.random() ? .walk : .drop
            case let style: return style
            }
        }()
        guard style == .drop else {
            animate(panel, to: target, seconds: walkInSeconds, completion: arrived)
            return
        }
        state.pose = .idle
        state.facingLeft = state.fromRight
        panel.setFrame(NSRect(x: target.minX, y: screen.maxY, width: size.width, height: size.height), display: false)
        fall(panel, to: target.minY, then: arrived)
    }

    /// Gravity, a few shrinking bounces and a squash on every landing, stepped at 60 fps.
    private func fall(_ panel: NSPanel, to floor: CGFloat, then landed: @escaping () -> Void) {
        let gravity: CGFloat = 2800, restitution: CGFloat = 0.34, step = 1.0 / 60
        var y = panel.frame.minY, velocity: CGFloat = 0
        state.airborne = true
        fallTimer?.invalidate()
        let timer = Timer(timeInterval: step, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            velocity -= gravity * CGFloat(step)
            y += velocity * CGFloat(step)
            if y <= floor {
                y = floor
                let speed = -velocity
                self.state.impactAt = Date()
                self.state.impactStrength = min(speed / 2200, 1)
                if speed > 260 {
                    velocity = speed * restitution
                } else {
                    timer.invalidate()
                    self.fallTimer = nil
                    self.state.airborne = false
                    panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: floor))
                    // Let the landing squash settle before the next move.
                    self.after(0.35, landed)
                    return
                }
            }
            panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: y))
        }
        RunLoop.main.add(timer, forMode: .common)
        fallTimer = timer
    }

    // MARK: - Following the cursor

    /// While on screen the character leans toward the cursor, turns to face it when it's far
    /// off to the other side, and hops when the cursor touches it.
    private func followCursor() {
        cursorTimer?.invalidate()
        state.lookX = 0
        cursorWasOnCharacter = false
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.trackCursor() }
        RunLoop.main.add(timer, forMode: .common)
        cursorTimer = timer
    }

    private func trackCursor() {
        guard let panel, panel.isVisible else { return }
        let mouse = NSEvent.mouseLocation
        // The character stands in a 210×310 box at the panel's bottom-left (or bottom-right) corner.
        let box = NSRect(x: state.fromRight ? panel.frame.maxX - 210 : panel.frame.minX, y: panel.frame.minY,
                         width: 210, height: 310)
        let target = max(-1, min(1, (mouse.x - box.midX) / 500))
        state.lookX += (target - state.lookX) * 0.12

        let settled = state.stage == .asking || state.stage == .answered
        // Turn around only for a cursor well off to the other side, so it doesn't flip-flop.
        if settled, state.pose == .idle {
            if mouse.x < box.minX - 120 { state.facingLeft = true }
            if mouse.x > box.maxX + 120 { state.facingLeft = false }
        }

        let onCharacter = box.insetBy(dx: 40, dy: 20).contains(mouse)
        if onCharacter, !cursorWasOnCharacter, settled, !state.airborne,
           (state.hopAt.map { Date().timeIntervalSince($0) > 1.2 } ?? true) {
            state.hopAt = Date()
        }
        cursorWasOnCharacter = onCharacter
    }

    private func stopMotion() {
        fallTimer?.invalidate()
        fallTimer = nil
        cursorTimer?.invalidate()
        cursorTimer = nil
        state.airborne = false
    }

    // MARK: - Helpers

    /// How long to stay in a pose: one full play of its video clip (up to 10 s), or `atLeast`.
    private func clipSeconds(_ pose: CharacterPose, atLeast minimum: Double, _ done: @escaping (Double) -> Void) {
        guard let url = state.sprites.clips[pose] else { return done(minimum) }
        Task { @MainActor in
            let length = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? minimum
            done(min(max(length, minimum), 10))
        }
    }

    /// Where the character stops: a few steps in from the edge (12% of the screen width), not
    /// squeezed into the corner.
    private func stopX(in screen: NSRect, fromRight: Bool) -> CGFloat {
        let inset = max(24, screen.width * 0.12)
        return fromRight ? screen.maxX - size.width - inset : screen.minX + inset
    }

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
