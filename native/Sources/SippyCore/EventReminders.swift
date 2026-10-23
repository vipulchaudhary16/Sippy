import Foundation

/// A calendar event as Sippy needs it, independent of EventKit so the logic can be checked.
public struct UpcomingEvent: Equatable {
    /// Stable per occurrence (recurring events share an identifier, so the start time is part of it).
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let declined: Bool
    public let meetingLink: URL?

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false,
                declined: Bool = false, meetingLink: URL? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.declined = declined
        self.meetingLink = meetingLink
    }
}

/// Decides which events need a knock, and when the next one is due.
public struct EventReminderPlanner {
    public let leadMinutes: Int
    /// How long after the start time a missed alert is still worth showing (e.g. after unlocking).
    public let lateGrace: TimeInterval

    public init(leadMinutes: Int, lateGrace: TimeInterval = 2 * 60) {
        self.leadMinutes = leadMinutes
        self.lateGrace = lateGrace
    }

    func alertTime(for event: UpcomingEvent) -> Date {
        event.start.addingTimeInterval(-TimeInterval(leadMinutes * 60))
    }

    func wanted(_ event: UpcomingEvent) -> Bool {
        !event.isAllDay && !event.declined
    }

    /// Events whose alert time has come, that haven't started more than `lateGrace` ago,
    /// and haven't been alerted yet. Soonest first.
    public func due(_ events: [UpcomingEvent], now: Date, alerted: Set<String>) -> [UpcomingEvent] {
        events
            .filter { wanted($0) && !alerted.contains($0.id) }
            .filter { alertTime(for: $0) <= now && now < $0.start.addingTimeInterval(lateGrace) }
            .sorted { $0.start < $1.start }
    }

    /// The next upcoming event worth alerting about (for the menu).
    public func next(_ events: [UpcomingEvent], now: Date) -> UpcomingEvent? {
        events.filter { wanted($0) && $0.start > now }.min { $0.start < $1.start }
    }
}

public enum EventText {
    /// "starts in 5 min" / "starts in 1 min" / "is starting now" / "started 1 min ago".
    public static func when(_ start: Date, now: Date) -> String {
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded())
        switch minutes {
        case 1...: return "starts in \(minutes) min"
        case 0: return "is starting now"
        default: return "started \(-minutes) min ago"
        }
    }

    /// The bubble text for one or more events due together.
    public static func headline(_ events: [UpcomingEvent], now: Date) -> String {
        guard let first = events.first else { return "" }
        let name = first.title.isEmpty ? "Your event" : "“\(first.title)”"
        let more = events.count > 1 ? "\n(+\(events.count - 1) more)" : ""
        return "Knock knock! 🚪\n\(name) \(when(first.start, now: now))\(more)"
    }
}

/// Finds a video-call link in an event's URL, location, or notes.
public enum MeetingLink {
    static let patterns = [
        #"https://[\w.-]*zoom\.us/(j|my|w)/[^\s<>"']+"#,
        #"https://meet\.google\.com/[a-z0-9-]+"#,
        #"https://teams\.microsoft\.com/l/meetup-join/[^\s<>"']+"#,
        #"https://teams\.live\.com/meet/[^\s<>"']+"#,
        #"https://[\w.-]*webex\.com/[^\s<>"']+"#,
        #"https://facetime\.apple\.com/join[^\s<>"']+"#,
        #"https://whereby\.com/[^\s<>"']+"#,
    ]

    public static func find(in texts: [String?]) -> URL? {
        for text in texts.compactMap({ $0 }) {
            for pattern in patterns {
                if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
                   let url = URL(string: String(text[range])) {
                    return url
                }
            }
        }
        return nil
    }
}
