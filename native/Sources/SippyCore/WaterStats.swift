import Foundation

public struct DayCount: Equatable, Identifiable {
    public let day: Date
    public let count: Int
    public var id: Date { day }
}

public struct WaterStats {
    public let entries: [Date]
    public let calendar: Calendar

    public init(entries: [Date], calendar: Calendar = .current) {
        self.entries = entries
        self.calendar = calendar
    }

    public func count(on day: Date) -> Int {
        entries.filter { calendar.isDate($0, inSameDayAs: day) }.count
    }

    /// Consecutive days meeting the goal, ending today. Today counts only once met,
    /// so an in-progress day doesn't break yesterday's streak.
    public func streak(goal: Int, now: Date = Date()) -> Int {
        guard goal > 0 else { return 0 }
        var day = calendar.startOfDay(for: now)
        if count(on: day) < goal {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var streak = 0
        while count(on: day) >= goal {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    /// Oldest first, ending today.
    public func lastDays(_ n: Int, now: Date = Date()) -> [DayCount] {
        let today = calendar.startOfDay(for: now)
        return (0..<n).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return DayCount(day: day, count: count(on: day))
        }
    }
}
