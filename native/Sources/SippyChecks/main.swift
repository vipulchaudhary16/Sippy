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
    log.log(at: day(1))
    log.log(at: day(2))
    check(IntakeLog(fileURL: url).entries.count == 2)
    check(log.removeLast() == day(2))
    check(IntakeLog(fileURL: url).entries == [day(1)])
}

test("count on day ignores other days") {
    let stats = WaterStats(entries: [day(1, 0), day(1, 23), day(2, 0)], calendar: cal)
    check(stats.count(on: day(1)) == 2)
    check(stats.count(on: day(3)) == 0)
}

test("streak skips unfinished today") {
    // Days 18-20 met goal 2, today (21) only has 1.
    let entries = [18, 18, 19, 19, 20, 20, 21].map { day($0) }
    let stats = WaterStats(entries: entries, calendar: cal)
    check(stats.streak(goal: 2, now: day(21)) == 3)
    check(stats.streak(goal: 1, now: day(21)) == 4)
    check(stats.streak(goal: 3, now: day(21)) == 0)
    check(stats.streak(goal: 0, now: day(21)) == 0)
}

test("last days is oldest first and ends today") {
    let stats = WaterStats(entries: [day(21), day(21), day(15)], calendar: cal)
    let week = stats.lastDays(7, now: day(21))
    check(week.count == 7)
    check(week.first?.day == cal.startOfDay(for: day(15)))
    check(week.first?.count == 1)
    check(week.last?.count == 2)
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

print(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
