import Foundation

/// The daily window when reminders may fire, as minutes after midnight.
/// `from > to` wraps past midnight (22:00–06:00); `from == to` means all day.
public struct ActiveHours: Equatable {
    public let from: Int
    public let to: Int

    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if from == to { return true }
        if from < to { return minute >= from && minute < to }
        return minute >= from || minute < to
    }

    /// The next time the window opens strictly after `date`.
    public func nextStart(after date: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.date(bySettingHour: from / 60, minute: from % 60, second: 0, of: date)!
        if today > date { return today }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!
        return calendar.date(bySettingHour: from / 60, minute: from % 60, second: 0, of: tomorrow)!
    }

    /// "11:00" style, for labels.
    public static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
