import Charts
import SwiftUI
import SippyCore

struct DashboardView: View {
    @ObservedObject var model: AppModel

    private var stats: WaterStats { model.stats }
    private var goal: Int { model.settings.dailyGoal }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 24) {
                    GlassGauge(count: model.todayCount, goal: goal)
                        .frame(width: 90, height: 130)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(model.todayCount) of \(goal) glasses")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text(encouragement)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button { model.logGlass() } label: { Label("Log a glass", systemImage: "plus") }
                                .buttonStyle(.borderedProminent)
                            Button("Undo") { model.undoLastGlass() }
                                .disabled(stats.count(on: Date()) == 0)
                        }
                        .padding(.top, 4)
                    }
                }

                HStack(spacing: 12) {
                    StatTile(title: "Streak", value: "\(stats.streak(goal: goal)) 🔥", caption: "days at goal")
                    StatTile(title: "7-day average", value: String(format: "%.1f", weekAverage), caption: "glasses / day")
                    StatTile(title: "All time", value: "\(model.entries.count)", caption: "glasses logged")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 7 days").font(.headline)
                    Chart {
                        ForEach(stats.lastDays(7)) { d in
                            BarMark(x: .value("Day", d.day, unit: .day), y: .value("Glasses", d.count))
                                .foregroundStyle(d.count >= goal ? Color.blue : Color.blue.opacity(0.45))
                                .cornerRadius(5)
                        }
                        RuleMark(y: .value("Goal", goal))
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
                        Text("No glasses logged yet. Your first one is a click away 💧")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(stats.lastDays(30).reversed().filter { $0.count > 0 }) { d in
                            HStack {
                                Text(d.day, format: .dateTime.weekday(.wide).month().day())
                                Spacer()
                                Text(String(repeating: "💧", count: min(d.count, 12)))
                                Text("\(d.count)").monospacedDigit().frame(width: 28, alignment: .trailing)
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
        return Double(week.map(\.count).reduce(0, +)) / Double(week.count)
    }

    private var encouragement: String {
        let left = goal - model.todayCount
        switch left {
        case ..<1: return "Goal reached. You're a hydration hero! 🏆"
        case 1: return "Just one more glass to go!"
        default: return "\(left) more to reach today's goal."
        }
    }
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
    let count: Int
    let goal: Int

    var body: some View {
        let level = min(1, Double(count) / Double(max(goal, 1)))
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
