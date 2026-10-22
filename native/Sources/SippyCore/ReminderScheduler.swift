import Foundation

public enum ReminderKind {
    case interval
    case snooze
}

public enum ReminderPlan {
    public static func delay(for kind: ReminderKind, settings: AppSettings) -> TimeInterval {
        let s = settings.clamped()
        switch kind {
        case .interval: return TimeInterval(s.intervalMinutes * 60)
        case .snooze: return TimeInterval(s.snoozeMinutes * 60)
        }
    }
}

/// One pending reminder at a time. Uses wall-clock deadlines checked by a short
/// repeating timer, so a reminder that came due while the Mac slept still fires on wake.
public final class ReminderScheduler {
    public private(set) var nextFire: Date?
    /// While true (paused, screen locked) a due reminder waits instead of firing.
    public var shouldHold: () -> Bool = { false }
    private var ticker: Timer?
    private let onFire: () -> Void

    public init(onFire: @escaping () -> Void) {
        self.onFire = onFire
    }

    public func schedule(after seconds: TimeInterval) {
        nextFire = Date().addingTimeInterval(seconds)
        if ticker == nil {
            let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.tick() }
            RunLoop.main.add(t, forMode: .common)
            ticker = t
        }
    }

    public func cancel() {
        nextFire = nil
    }

    public func tick(now: Date = Date()) {
        guard !shouldHold(), let due = nextFire, now >= due else { return }
        nextFire = nil
        onFire()
    }
}
