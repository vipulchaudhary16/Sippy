import Foundation
import SippyCore

var failures = 0
var current = ""

func check(_ condition: @autoclosure () -> Bool, _ message: String = "", line: Int = #line) {
    if !condition() {
        failures += 1
        print("  ✗ \(current) (line \(line)) \(message)")
    }
}

func test(_ name: String, _ body: () throws -> Void) {
    current = name
    let before = failures
    do { try body() } catch { failures += 1; print("  ✗ \(name) threw \(error)") }
    if failures == before { print("  ✓ \(name)") }
}

let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

func day(_ d: Int, _ hour: Int = 12) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 10, day: d, hour: hour))!
}

test("settings clamp rejects zero and negative") {
    var s = AppSettings()
    s.intervalMinutes = 0
    s.snoozeMinutes = -5
    s.dailyGoal = 0
    s.volume = 3
    let c = s.clamped()
    check(c.intervalMinutes == 1)
    check(c.snoozeMinutes == 1)
    check(c.dailyGoal == 1)
    check(c.volume == 1)
}

test("settings round-trip through store") {
    let defaults = UserDefaults(suiteName: "sippy.checks.\(UUID())")!
    let store = SettingsStore(defaults: defaults)
    var s = AppSettings()
    s.intervalMinutes = 30
    s.musicPaths = ["/tmp/a.mp3"]
    store.save(s)
    check(store.load() == s)
}

test("settings decode tolerates missing fields") {
    let s = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"intervalMinutes":20}"#.utf8))
    check(s.intervalMinutes == 20)
    check(s.dailyGoal == 8)
}

test("intake log persists and undoes") {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("sippy-\(UUID()).json")
    let log = IntakeLog(fileURL: url)
    log.log(ml: 250, at: day(1))
    log.log(ml: 500, at: day(2))
    check(IntakeLog(fileURL: url).entries.count == 2)
    check(log.removeLast() == IntakeEntry(date: day(2), ml: 500))
    check(IntakeLog(fileURL: url).entries == [IntakeEntry(date: day(1), ml: 250)])
}

test("intake log migrates the old timestamp-only format") {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("sippy-\(UUID()).json")
    try JSONEncoder().encode([day(2), day(1)]).write(to: url)
    let entries = IntakeLog(fileURL: url).entries
    check(entries == [IntakeEntry(date: day(1), ml: 250), IntakeEntry(date: day(2), ml: 250)])
}

func entries(_ pairs: [(Int, Int)]) -> [IntakeEntry] {
    pairs.map { IntakeEntry(date: day($0.0), ml: $0.1) }
}

test("total on day sums ml and ignores other days") {
    let stats = WaterStats(entries: [IntakeEntry(date: day(1, 0), ml: 250), IntakeEntry(date: day(1, 23), ml: 100),
                                     IntakeEntry(date: day(2, 0), ml: 250)], calendar: cal)
    check(stats.total(on: day(1)) == 350)
    check(stats.total(on: day(3)) == 0)
    check(stats.allTimeML == 600)
}

test("streak skips unfinished today") {
    // Days 18-20 reached 500 ml, today (21) only 250.
    let stats = WaterStats(entries: entries([(18, 500), (19, 250), (19, 250), (20, 600), (21, 250)]), calendar: cal)
    check(stats.streak(goalML: 500, now: day(21)) == 3)
    check(stats.streak(goalML: 250, now: day(21)) == 4)
    check(stats.streak(goalML: 700, now: day(21)) == 0)
    check(stats.streak(goalML: 0, now: day(21)) == 0)
}

test("last days is oldest first and ends today") {
    let stats = WaterStats(entries: entries([(21, 250), (21, 250), (15, 100)]), calendar: cal)
    let week = stats.lastDays(7, now: day(21))
    check(week.count == 7)
    check(week.first?.day == cal.startOfDay(for: day(15)))
    check(week.first?.ml == 100)
    check(week.last?.ml == 500)
}

test("glasses mode speaks in glasses") {
    var s = AppSettings()
    s.dailyGoal = 8
    s.glassML = 250
    let a = Amounts(s)
    check(s.goalML == 2000)
    check(a.describe(250) == "1 glass", a.describe(250))
    check(a.describe(750) == "3 glasses", a.describe(750))
    check(a.describe(375) == "1.5 glasses", a.describe(375))
    check(a.format(8.0 / 7) == "1.1", a.format(8.0 / 7))
    check(a.progress(500) == "2 of 8 glasses", a.progress(500))
    check(a.drinkOptions == [DrinkOption(label: "Yes, I drank!", ml: 250)])
}

test("bottle mode speaks in litres and bottle fractions") {
    var s = AppSettings()
    s.trackingMode = .bottle
    s.bottleML = 1000
    s.dailyGoalML = 2500
    let a = Amounts(s)
    check(s.goalML == 2500)
    check(a.progress(1250) == "1.25 of 2.5 L", a.progress(1250))
    // Today + remaining must add up to the goal on screen (0.3 + 2.3 used to show for 0.25 + 2.25).
    check(a.progress(250) == "0.25 of 2.5 L", a.progress(250))
    check(a.describe(2250) == "2.25 L", a.describe(2250))
    check(a.format(250.0 / 7 / 1000) == "0.04", a.format(250.0 / 7 / 1000))
    check(a.format(0) == "0", a.format(0))
    check(a.describe(2000) == "2 L", a.describe(2000))
    check(a.goalInBottles == "2½ bottles", a.goalInBottles)
    check(a.drinkOptions.map(\.ml) == [100, 250, 500, 1000])
    s.dailyGoalML = 1000
    check(Amounts(s).goalInBottles == "1 bottle", Amounts(s).goalInBottles)
    s.bottleML = 750
    s.dailyGoalML = 3000
    check(Amounts(s).goalInBottles == "4 bottles", Amounts(s).goalInBottles)
}

test("settings from before bottle mode load as glasses") {
    let s = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"dailyGoal":6}"#.utf8))
    check(s.trackingMode == .glasses)
    check(s.entrySide == .left)
    check(s.verticalPosition == .bottom)
    check(s.activeHours == nil, "reminder hours are off unless turned on")
    check(s.goalML == 1500)
}

test("scheduler plan picks interval, snooze, and pause") {
    var s = AppSettings()
    s.intervalMinutes = 45
    s.snoozeMinutes = 10
    check(ReminderPlan.delay(for: .interval, settings: s) == 45 * 60)
    check(ReminderPlan.delay(for: .snooze, settings: s) == 10 * 60)
}

test("scheduler fires once when due, holds while held") {
    var fired = 0
    var hold = true
    let scheduler = ReminderScheduler { fired += 1 }
    scheduler.shouldHold = { hold }
    scheduler.schedule(after: 60)
    let due = scheduler.nextFire!
    scheduler.tick(now: due.addingTimeInterval(-1))
    check(fired == 0)
    scheduler.tick(now: due.addingTimeInterval(10))
    check(fired == 0, "held reminder must not fire")
    hold = false
    scheduler.tick(now: due.addingTimeInterval(10))
    scheduler.tick(now: due.addingTimeInterval(20))
    check(fired == 1, "fires exactly once")
    check(scheduler.nextFire == nil)
}

test("log amounts resolve by name or millilitres") {
    var s = AppSettings()
    s.glassML = 300
    s.bottleML = 1000
    let a = Amounts(s)
    check(a.ml(forAmount: "glass") == 300)
    check(a.ml(forAmount: "sips") == 100)
    check(a.ml(forAmount: "Quarter") == 250)
    check(a.ml(forAmount: "half") == 500)
    check(a.ml(forAmount: "bottle") == 1000)
    check(a.ml(forAmount: "330") == 330)
    check(a.ml(forAmount: "99999") == 5000, "capped")
    check(a.ml(forAmount: "0") == nil)
    check(a.ml(forAmount: "coffee") == nil)
    check(a.spotlightActions.map(\.amount) == ["glass"])
    s.trackingMode = .bottle
    check(Amounts(s).spotlightActions.map(\.amount) == ["sips", "quarter", "half", "bottle"])
    // Every offered action must resolve.
    check(Amounts(s).spotlightActions.allSatisfy { Amounts(s).ml(forAmount: $0.amount) != nil })
}

func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 10, day: d, hour: h, minute: m))!
}

test("active hours: daytime window") {
    let hours = ActiveHours(from: 11 * 60, to: 19 * 60)
    check(!hours.contains(at(1, 10, 59), calendar: cal))
    check(hours.contains(at(1, 11), calendar: cal))
    check(hours.contains(at(1, 18, 59), calendar: cal))
    check(!hours.contains(at(1, 19), calendar: cal), "end time is exclusive")
    check(hours.nextStart(after: at(1, 8), calendar: cal) == at(1, 11), "same morning")
    check(hours.nextStart(after: at(1, 20), calendar: cal) == at(2, 11), "next morning")
    check(hours.nextStart(after: at(1, 11), calendar: cal) == at(2, 11), "strictly after")
}

test("active hours: overnight window and all-day") {
    let night = ActiveHours(from: 22 * 60, to: 6 * 60)
    check(night.contains(at(1, 23), calendar: cal))
    check(night.contains(at(1, 3), calendar: cal))
    check(!night.contains(at(1, 12), calendar: cal))
    check(ActiveHours(from: 600, to: 600).contains(at(1, 3), calendar: cal))
}

test("reminders outside active hours wait for the window to open") {
    var s = AppSettings()
    s.intervalMinutes = 45
    s.activeHoursEnabled = true
    s.activeFromMinutes = 11 * 60
    s.activeToMinutes = 19 * 60
    check(ReminderPlan.fireDate(for: .interval, settings: s, now: at(1, 12), calendar: cal) == at(1, 12, 45))
    check(ReminderPlan.fireDate(for: .interval, settings: s, now: at(1, 18, 30), calendar: cal) == at(2, 11),
          "would land at 19:15, so tomorrow 11:00")
    check(ReminderPlan.fireDate(for: .interval, settings: s, now: at(1, 7), calendar: cal) == at(1, 11))
    s.activeHoursEnabled = false
    check(ReminderPlan.fireDate(for: .interval, settings: s, now: at(1, 18, 30), calendar: cal) == at(1, 19, 15))
}

func event(_ id: String, _ start: Date, allDay: Bool = false, declined: Bool = false) -> UpcomingEvent {
    UpcomingEvent(id: id, title: id, start: start, end: start.addingTimeInterval(1800), isAllDay: allDay, declined: declined)
}

test("event reminders fire at the lead time, once, and skip all-day and declined") {
    let planner = EventReminderPlanner(leadMinutes: 5)
    let standup = event("standup", at(1, 10, 30))
    let events = [standup, event("holiday", at(1, 0), allDay: true), event("skip", at(1, 10, 30), declined: true)]
    check(planner.due(events, now: at(1, 10, 24), alerted: []).isEmpty, "too early")
    check(planner.due(events, now: at(1, 10, 25), alerted: []).map(\.id) == ["standup"])
    check(planner.due(events, now: at(1, 10, 25), alerted: ["standup"]).isEmpty, "only once")
    check(planner.due(events, now: at(1, 10, 31), alerted: []).map(\.id) == ["standup"], "late but within grace")
    check(planner.due(events, now: at(1, 10, 33), alerted: []).isEmpty, "too late")
    check(planner.next(events, now: at(1, 9))?.id == "standup")
}

test("events due together come soonest first") {
    let planner = EventReminderPlanner(leadMinutes: 10)
    let due = planner.due([event("b", at(1, 11, 5)), event("a", at(1, 11))], now: at(1, 10, 56), alerted: [])
    check(due.map(\.id) == ["a", "b"])
    check(EventText.headline(due, now: at(1, 10, 56)) == "Knock knock! 🚪\n“a” starts in 4 min\n(+1 more)",
          EventText.headline(due, now: at(1, 10, 56)))
}

test("event wording") {
    check(EventText.when(at(1, 10, 5), now: at(1, 10)) == "starts in 5 min")
    check(EventText.when(at(1, 10), now: at(1, 10)) == "is starting now")
    check(EventText.when(at(1, 10), now: at(1, 10, 1)) == "started 1 min ago")
}

test("meeting links are found in url, location, or notes") {
    check(MeetingLink.find(in: [nil, "Room 4", "Join: https://us02web.zoom.us/j/123456?pwd=abc thanks"])?.absoluteString
          == "https://us02web.zoom.us/j/123456?pwd=abc")
    check(MeetingLink.find(in: ["https://meet.google.com/abc-defg-hij"])?.host == "meet.google.com")
    check(MeetingLink.find(in: ["<https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0>"])?.host == "teams.microsoft.com")
    check(MeetingLink.find(in: ["Lunch at the cafe", nil]) == nil)
}

print(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
