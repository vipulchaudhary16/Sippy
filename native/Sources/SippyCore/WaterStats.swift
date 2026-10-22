import Foundation

public struct DayTotal: Equatable, Identifiable {
    public let day: Date
    public let ml: Int
    public var id: Date { day }
}

public struct WaterStats {
    public let entries: [IntakeEntry]
    public let calendar: Calendar

    public init(entries: [IntakeEntry], calendar: Calendar = .current) {
        self.entries = entries
        self.calendar = calendar
    }

    public func total(on day: Date) -> Int {
        entries.filter { calendar.isDate($0.date, inSameDayAs: day) }.map(\.ml).reduce(0, +)
    }

    public var allTimeML: Int { entries.map(\.ml).reduce(0, +) }

    /// Consecutive days meeting the goal, ending today. Today counts only once met,
    /// so an in-progress day doesn't break yesterday's streak.
    public func streak(goalML: Int, now: Date = Date()) -> Int {
        guard goalML > 0 else { return 0 }
        var day = calendar.startOfDay(for: now)
        if total(on: day) < goalML {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var streak = 0
        while total(on: day) >= goalML {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    /// Oldest first, ending today.
    public func lastDays(_ n: Int, now: Date = Date()) -> [DayTotal] {
        let today = calendar.startOfDay(for: now)
        return (0..<n).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return DayTotal(day: day, ml: total(on: day))
        }
    }
}
