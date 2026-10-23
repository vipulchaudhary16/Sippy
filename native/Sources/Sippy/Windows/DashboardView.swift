import Charts
import SwiftUI
import SippyCore

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var calendar: CalendarWatcher

    init(model: AppModel) {
        self.model = model
        self.calendar = model.calendar
    }

    private var stats: WaterStats { model.stats }
    private var amounts: Amounts { model.amounts }
    private var goalML: Int { model.settings.goalML }
    private var bottleMode: Bool { model.settings.trackingMode == .bottle }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if model.settings.eventRemindersEnabled && calendar.isAuthorized {
                    UpNextCard(events: calendar.upcomingToday(limit: 4), leadMinutes: model.settings.eventLeadMinutes)
                }

                Label("Water", systemImage: "drop.fill").font(.title3.bold()).foregroundStyle(.blue)

                HStack(alignment: .center, spacing: 24) {
                    GlassGauge(fraction: Double(model.todayML) / Double(max(goalML, 1)))
                        .frame(width: 90, height: 130)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(amounts.progress(model.todayML))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text(encouragement)
                            .foregroundStyle(.secondary)
                        HStack {
                            if bottleMode {
                                Menu {
                                    ForEach(amounts.drinkOptions) { option in
                                        Button("\(option.label) (\(option.ml) ml)") { model.log(ml: option.ml) }
                                    }
                                } label: { Label("Log a drink", systemImage: "plus") }
                                    .fixedSize()
                            } else {
                                Button { model.log(ml: amounts.quickLog.ml) } label: { Label("Log a glass", systemImage: "plus") }
                                    .buttonStyle(.borderedProminent)
                            }
                            Button("Undo") { model.undoLast() }
                                .disabled(stats.total(on: Date()) == 0)
                        }
                        .padding(.top, 4)
                    }
                }

                HStack(spacing: 12) {
                    StatTile(title: "Streak", value: "\(stats.streak(goalML: goalML)) 🔥", caption: "days at goal")
                    StatTile(title: "7-day average", value: amounts.format(weekAverage), caption: "\(amounts.unitName) / day")
                    StatTile(title: "All time", value: amounts.describe(stats.allTimeML), caption: "logged")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 7 days").font(.headline)
                    Chart {
                        ForEach(stats.lastDays(7)) { d in
                            BarMark(x: .value("Day", d.day, unit: .day), y: .value(amounts.unitName, amounts.value(d.ml)))
                                .foregroundStyle(d.ml >= goalML ? Color.blue : Color.blue.opacity(0.45))
                                .cornerRadius(5)
                        }
                        RuleMark(y: .value("Goal", amounts.value(goalML)))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(.secondary)
                            .annotation(position: .top, alignment: .leading) {
                                Text("goal").font(.caption2).foregroundStyle(.secondary)
                            }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .frame(height: 170)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("History").font(.headline)
                    if model.entries.isEmpty {
                        Text("Nothing logged yet. Your first sip is a click away 💧")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(stats.lastDays(30).reversed().filter { $0.ml > 0 }) { d in
                            HStack {
                                Text(d.day, format: .dateTime.weekday(.wide).month().day())
                                Spacer()
                                if d.ml >= goalML { Text("✅") }
                                Text(amounts.describe(d.ml)).monospacedDigit()
                            }
                            .padding(.vertical, 2)
                            Divider()
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 460, minHeight: 480)
    }

    private var weekAverage: Double {
        let week = stats.lastDays(7)
        return week.map { amounts.value($0.ml) }.reduce(0, +) / Double(week.count)
    }

    private var encouragement: String {
        let left = goalML - model.todayML
        if left <= 0 { return "Goal reached. You're a hydration hero! 🏆" }
        if bottleMode { return "\(amounts.describe(left)) more to reach today's goal." }
        return left <= model.settings.glassML ? "Just one more glass to go!" : "\(amounts.describe(left)) more to reach today's goal."
    }
}

/// Today's remaining meetings, with Join buttons for ones that have a call link.
struct UpNextCard: View {
    let events: [UpcomingEvent]
    let leadMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Up next", systemImage: "calendar").font(.title3.bold()).foregroundStyle(.orange)
                Spacer()
                Text("Knocks \(leadMinutes) min before").font(.caption).foregroundStyle(.secondary)
            }
            if events.isEmpty {
                Text("No more meetings today 🎉").foregroundStyle(.secondary)
            }
            ForEach(events, id: \.id) { event in
                HStack(spacing: 12) {
                    Text(event.start <= Date() ? "Now" : event.start.formatted(date: .omitted, time: .shortened))
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(event.start <= Date() ? .orange : .primary)
                        .frame(width: 72, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title.isEmpty ? "Event" : event.title).lineLimit(1)
                        Text(EventText.when(event.start, now: Date()).capitalizedFirst)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let link = event.meetingLink {
                        Button { NSWorkspace.shared.open(link) } label: { Label("Join", systemImage: "video.fill") }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.08)))
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

struct StatTile: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.08)))
    }
}

/// A glass that fills up as the day's count approaches the goal.
struct GlassGauge: View {
    let fraction: Double

    var body: some View {
        let level = min(1, max(0, fraction))
        GeometryReader { g in
            ZStack(alignment: .bottom) {
                GlassShape().fill(Color.blue.opacity(0.06))
                Rectangle()
                    .fill(LinearGradient(colors: [Color(red: 0.45, green: 0.8, blue: 1), Color(red: 0.2, green: 0.5, blue: 0.95)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: g.size.height * level)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: level)
                GlassShape().stroke(Color.blue.opacity(0.6), lineWidth: 3)
            }
            .clipShape(GlassShape())
            .overlay(GlassShape().stroke(Color.blue.opacity(0.6), lineWidth: 3))
        }
    }
}

struct GlassShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let inset = r.width * 0.12
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - inset, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + inset, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
