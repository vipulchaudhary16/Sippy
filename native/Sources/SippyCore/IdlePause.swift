import Foundation

/// While nobody is at the Mac the reminder countdown stops. When they come back it carries on
/// from where it stood when they left, but never sooner than a short settle-in time.
public enum IdlePause {
    /// Seconds until the next reminder once the user is back, given when they went idle.
    public static func resumeDelay(nextFire: Date, idleSince: Date, settle: TimeInterval = 60) -> TimeInterval {
        max(nextFire.timeIntervalSince(idleSince), settle)
    }
}
