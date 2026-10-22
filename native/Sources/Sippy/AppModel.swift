import AppKit
import Combine
import SippyCore

/// Shared state for the menu bar, the overlay, and the windows.
final class AppModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var entries: [Date]
    @Published var paused = false
    private var sessionLocked = false
    private var displayAsleep = false
    private var screenLocked: Bool { sessionLocked || displayAsleep }

    let store = SettingsStore()
    let log = IntakeLog(fileURL: IntakeLog.defaultURL())
    let audio = AudioPlayer()
    lazy var scheduler: ReminderScheduler = {
        let s = ReminderScheduler { [weak self] in self?.onReminderDue() }
        s.shouldHold = { [weak self] in
            guard let self else { return true }
            return self.paused || self.screenLocked || self.overlay.isShowing
        }
        return s
    }()
    lazy var overlay = OverlayController(model: self)

    init() {
        settings = store.load()
        entries = log.entries
        observeScreenLock()
    }

    var stats: WaterStats { WaterStats(entries: entries) }
    var todayCount: Int { stats.count(on: Date()) }

    func start() {
        scheduleNext(.interval)
    }

    func scheduleNext(_ kind: ReminderKind) {
        scheduler.schedule(after: ReminderPlan.delay(for: kind, settings: settings))
    }

    func remindNow() {
        guard !overlay.isShowing else { return }
        scheduler.cancel()
        overlay.show()
    }

    private func onReminderDue() {
        overlay.show()
    }

    // MARK: - Answers from the overlay

    func drank() {
        logGlass()
        scheduleNext(.interval)
    }

    func snooze() {
        scheduleNext(.snooze)
    }

    func logGlass() {
        log.log()
        entries = log.entries
    }

    func undoLastGlass() {
        log.removeLast()
        entries = log.entries
    }

    func update(_ change: (inout AppSettings) -> Void) {
        var s = settings
        change(&s)
        s = s.clamped()
        let intervalChanged = s.intervalMinutes != settings.intervalMinutes
        settings = s
        store.save(s)
        audio.apply(volume: s.volume, muted: s.muted)
        // A new interval applies right away rather than after the old one runs out.
        if intervalChanged && !overlay.isShowing { scheduleNext(.interval) }
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
