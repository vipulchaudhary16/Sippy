import AppKit
import EventKit
import SippyCore

/// Reads upcoming events from macOS Calendar (which includes Google, iCloud, Exchange and other
/// accounts added in System Settings → Internet Accounts) and asks the overlay to knock before them.
final class CalendarWatcher: ObservableObject {
    private(set) var store = EKEventStore()
    private unowned let model: AppModel
    @Published private(set) var events: [UpcomingEvent] = []
    /// Occurrence id -> start, so an event knocks once; pruned as events pass.
    private var alerted: [String: Date] = [:]
    private var ticker: Timer?
    private var lastRefresh = Date.distantPast
    @Published private(set) var accessChanged = 0

    init(model: AppModel) {
        self.model = model
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Access

    var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) { return status == .fullAccess }
        return status == .authorized
    }

    var isDenied: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .denied || status == .restricted
    }

    func requestAccess(_ done: @escaping (Bool) -> Void) {
        let finish: (Bool, Error?) -> Void = { granted, _ in
            DispatchQueue.main.async {
                // A fresh store sees calendars that became readable after the grant.
                self.store = EKEventStore()
                self.accessChanged += 1
                self.refresh()
                done(granted)
            }
        }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents(completion: finish)
        } else {
            store.requestAccess(to: .event, completion: finish)
        }
    }

    /// Every event calendar, for the Settings picker.
    var calendars: [EKCalendar] {
        isAuthorized ? store.calendars(for: .event).sorted { ($0.source.title, $0.title) < ($1.source.title, $1.title) } : []
    }

    // MARK: - Watching

    func start() {
        guard ticker == nil else { return }
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
        refresh()
    }

    /// The next event worth a knock, for the menu.
    var nextEvent: UpcomingEvent? {
        guard model.settings.eventRemindersEnabled, isAuthorized else { return nil }
        return EventReminderPlanner(leadMinutes: model.settings.eventLeadMinutes).next(events, now: Date())
    }

    func refresh() {
        lastRefresh = Date()
        guard model.settings.eventRemindersEnabled, isAuthorized else {
            events = []
            return
        }
        let wanted = Set(model.settings.eventCalendarIDs)
        let calendars = store.calendars(for: .event).filter { wanted.isEmpty || wanted.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else {
            events = []
            return
        }
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-10 * 60),
                                                 end: now.addingTimeInterval(24 * 3600), calendars: calendars)
        events = store.events(matching: predicate).map { e in
            let declined = e.attendees?.first { $0.isCurrentUser }?.participantStatus == .declined
            return UpcomingEvent(
                id: "\(e.calendarItemIdentifier)|\(e.startDate.timeIntervalSince1970)",
                title: e.title ?? "",
                start: e.startDate,
                end: e.endDate,
                isAllDay: e.isAllDay,
                declined: declined,
                meetingLink: MeetingLink.find(in: [e.url?.absoluteString, e.location, e.notes])
            )
        }
        alerted = alerted.filter { $0.value > now.addingTimeInterval(-3600) }
    }

    private func tick() {
        guard model.settings.eventRemindersEnabled, isAuthorized else { return }
        // Pick up new or moved events every few minutes even without a change notification.
        if Date().timeIntervalSince(lastRefresh) > 180 { refresh() }
        guard !model.isAway else { return }

        let planner = EventReminderPlanner(leadMinutes: model.settings.eventLeadMinutes)
        let due = planner.due(events, now: Date(), alerted: Set(alerted.keys))
        guard !due.isEmpty else { return }

        // A meeting beats a water reminder: send the water one off (snoozed) and knock next tick.
        if model.overlay.isAwaitingAnswer {
            model.overlay.answer(ml: nil)
            return
        }
        if model.overlay.showEvent(due) {
            due.forEach { alerted[$0.id] = $0.start }
        }
    }

    /// Settings → "Test knock": knock for the real next event (title, time, join link) without
    /// marking it as alerted, or a pretend meeting when the next 24 h are empty.
    func testKnock() {
        refresh()
        if let next = nextEvent {
            model.overlay.showEvent([next])
            return
        }
        let start = Date().addingTimeInterval(TimeInterval(model.settings.eventLeadMinutes * 60))
        model.overlay.showEvent([UpcomingEvent(id: "test", title: "Test meeting", start: start,
                                               end: start.addingTimeInterval(1800))])
    }

    /// "Standup at 10:30" for the test button, or nil when nothing is coming up.
    var nextEventSummary: String? {
        guard let next = nextEvent else { return nil }
        let time = next.start.formatted(date: .omitted, time: .shortened)
        let day = Calendar.current.isDateInToday(next.start) ? "" : " tomorrow"
        return "\(next.title.isEmpty ? "Event" : next.title) at \(time)\(day)"
    }
}
