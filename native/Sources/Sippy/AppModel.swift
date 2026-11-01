import AppKit
import Combine
import SippyCore

/// Shared state for the menu bar, the overlay, and the windows.
final class AppModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var entries: [IntakeEntry]
    @Published var paused = false
    private var sessionLocked = false
    private var displayAsleep = false
    private var screenLocked: Bool { sessionLocked || displayAsleep }
    /// Set while nobody has touched the mouse or keyboard for `idleMinutes`; when they went idle.
    private var idleSince: Date?
    private var idleTimer: Timer?
    /// Screen locked or asleep: nothing should pop up.
    var isAway: Bool { screenLocked }

    let store = SettingsStore()
    let intakeLog = IntakeLog(fileURL: IntakeLog.defaultURL())
    let audio = AudioPlayer()
    lazy var scheduler: ReminderScheduler = {
        let s = ReminderScheduler { [weak self] in self?.onReminderDue() }
        s.shouldHold = { [weak self] in
            guard let self else { return true }
            return self.paused || self.screenLocked || self.idleSince != nil || self.overlay.isShowing
        }
        return s
    }()
    lazy var overlay = OverlayController(model: self)
    let toast = Toast()
    lazy var calendar = CalendarWatcher(model: self)

    init() {
        settings = store.load()
        entries = intakeLog.entries
        observeScreenLock()
        watchIdle()
    }

    var stats: WaterStats { WaterStats(entries: entries) }
    var amounts: Amounts { Amounts(settings) }
    var todayML: Int { stats.total(on: Date()) }

    func start() {
        scheduleNext(.interval)
        SpotlightActions.sync(settings)
        calendar.start()
    }

    func scheduleNext(_ kind: ReminderKind) {
        scheduler.schedule(at: ReminderPlan.fireDate(for: kind, settings: settings))
    }

    func remindNow() {
        guard !overlay.isShowing else { return }
        scheduler.cancel()
        overlay.show()
    }

    private func onReminderDue() {
        // Came due outside reminder hours (e.g. hours changed, or a post-unlock grace period)?
        // Wait quietly for the window to open.
        if let hours = settings.activeHours, !hours.contains(Date()) {
            scheduler.schedule(at: hours.nextStart(after: Date()))
            return
        }
        overlay.show()
    }

    // MARK: - Answers from the overlay

    func drank(ml: Int) {
        log(ml: ml)
        scheduleNext(.interval)
    }

    func snooze() {
        scheduleNext(.snooze)
    }

    func log(ml: Int) {
        intakeLog.log(ml: ml)
        entries = intakeLog.entries
    }

    /// A drink logged outside the reminder (Spotlight action, sippy:// link, menu). If the
    /// character is asking right now it counts as the answer; otherwise log, restart the
    /// reminder countdown, and have the character cheer in the middle of the screen.
    func logFromAnywhere(ml: Int) {
        if overlay.isAwaitingAnswer {
            overlay.answer(ml: ml)
            return
        }
        drank(ml: ml)
        // Cheer in the middle of the screen; if the character is busy, a quiet toast instead.
        if !overlay.celebrate() {
            toast.show("Logged \(ml) ml · \(amounts.progress(todayML)) today")
        }
    }

    /// Handles `sippy://log?amount=glass|sips|quarter|half|bottle|<ml>`.
    func handle(url: URL) {
        guard url.scheme == "sippy", url.host == "log" else { return }
        let amount = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "amount" }?.value ?? "glass"
        guard let ml = amounts.ml(forAmount: amount) else {
            toast.show("Sippy doesn't know the amount “\(amount)”")
            return
        }
        logFromAnywhere(ml: ml)
    }

    func undoLast() {
        intakeLog.removeLast()
        entries = intakeLog.entries
    }

    func update(_ change: (inout AppSettings) -> Void) {
        let old = settings
        var s = settings
        change(&s)
        s = s.clamped()
        let timingChanged = s.intervalMinutes != settings.intervalMinutes || s.activeHours != settings.activeHours
        let actionsChanged = s.spotlightActions != settings.spotlightActions || s.trackingMode != settings.trackingMode
        settings = s
        store.save(s)
        audio.apply(volume: s.volume, muted: s.muted)
        // A new interval or reminder hours apply right away rather than after the old timer runs out.
        if timingChanged && !overlay.isShowing { scheduleNext(.interval) }
        if actionsChanged { SpotlightActions.sync(s) }
        if s.eventRemindersEnabled != old.eventRemindersEnabled || s.eventCalendarIDs != old.eventCalendarIDs {
            calendar.refresh()
        }
    }

    // MARK: - Away from the Mac

    /// Polls the time since the last mouse or keyboard input. No permission is needed for this.
    private func watchIdle() {
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.checkIdle() }
        RunLoop.main.add(t, forMode: .common)
        idleTimer = t
    }

    private func checkIdle() {
        let anyInput = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        let away = settings.pauseWhenIdle && idle >= TimeInterval(settings.idleMinutes * 60)
        if away, idleSince == nil {
            idleSince = Date().addingTimeInterval(-idle)
        } else if !away, let since = idleSince {
            idleSince = nil
            // Carry on from where the countdown stood when they walked away.
            if let due = scheduler.nextFire {
                scheduler.schedule(after: IdlePause.resumeDelay(nextFire: due, idleSince: since))
            }
        }
    }

    // MARK: - Screen lock

    /// Give the user a minute to settle in before a reminder that came due while away.
    private func screenUnlocked() {
        guard !screenLocked else { return }
        if let due = scheduler.nextFire, due.timeIntervalSinceNow < 60 {
            scheduler.schedule(after: 60)
        }
    }

    private func observeScreenLock() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.sessionLocked = true
        }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.sessionLocked = false
            self?.screenUnlocked()
        }
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.displayAsleep = true
        }
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.displayAsleep = false
            self?.screenUnlocked()
        }
    }
}
