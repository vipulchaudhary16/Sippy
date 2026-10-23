import AppKit
import EventKit
import ServiceManagement
import SwiftUI
import SippyCore
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable {
    case water, meetings, character, general

    var title: String {
        switch self {
        case .water: return "Water"
        case .meetings: return "Meetings"
        case .character: return "Character"
        case .general: return "General"
        }
    }

    var symbol: String {
        switch self {
        case .water: return "drop.fill"
        case .meetings: return "calendar"
        case .character: return "figure.wave"
        case .general: return "gearshape"
        }
    }
}

/// One tab of the Settings window.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    let tab: SettingsTab
    @ObservedObject private var calendar: CalendarWatcher
    @State private var calendarMessage: String?

    init(model: AppModel, tab: SettingsTab) {
        self.model = model
        self.tab = tab
        self.calendar = model.calendar
    }
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    private var s: AppSettings { model.settings }

    var body: some View {
        Form {
            switch tab {
            case .water:
                Section("How I drink") {
                    Picker("I drink from", selection: binding(\.trackingMode)) {
                        Text("Glasses").tag(TrackingMode.glasses)
                        Text("A bottle").tag(TrackingMode.bottle)
                    }
                    .pickerStyle(.segmented)
                    if s.trackingMode == .glasses {
                        Stepper("Glass size: **\(s.glassML) ml**", value: binding(\.glassML), in: 50...1000, step: 50)
                        Stepper("Daily goal: **\(s.dailyGoal) glasses** (\(String(format: "%g", Double(s.goalML) / 1000)) L)",
                                value: binding(\.dailyGoal), in: 1...30)
                    } else {
                        Stepper("Bottle size: **\(s.bottleML) ml**", value: binding(\.bottleML), in: 100...3000, step: 50)
                        Stepper("Daily goal: **\(String(format: "%g", Double(s.dailyGoalML) / 1000)) L** (\(Amounts(s).goalInBottles))",
                                value: binding(\.dailyGoalML), in: 250...10000, step: 250)
                        Text("When the character asks, tap how much you sipped: a few sips, ¼, ½ or the whole bottle.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Reminders") {
                    Stepper("Remind me every **\(s.intervalMinutes) min**",
                            value: binding(\.intervalMinutes), in: 1...240, step: s.intervalMinutes < 10 ? 1 : 5)
                    Stepper("Snooze for **\(s.snoozeMinutes) min**", value: binding(\.snoozeMinutes), in: 1...120)
                    Stepper("If I don't answer, snooze after **\(s.autoSnoozeMinutes) min**",
                            value: binding(\.autoSnoozeMinutes), in: 1...30)
                    Button("Show the reminder now") { model.remindNow() }
                }

                Section("Reminder hours") {
                    Toggle("Only remind me during set hours", isOn: binding(\.activeHoursEnabled))
                    if s.activeHoursEnabled {
                        DatePicker("From", selection: timeBinding(\.activeFromMinutes), displayedComponents: .hourAndMinute)
                        DatePicker("To", selection: timeBinding(\.activeToMinutes), displayedComponents: .hourAndMinute)
                        Text(hoursSummary)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

            case .meetings:
                Section("Meeting knocks") {
                    Toggle("Knock before my calendar events", isOn: eventToggle)
                    if s.eventRemindersEnabled && calendar.isAuthorized {
                        Stepper("Knock **\(s.eventLeadMinutes) min** before", value: binding(\.eventLeadMinutes), in: 1...120)
                        let _ = calendar.accessChanged
                        ForEach(calendar.calendars, id: \.calendarIdentifier) { cal in
                            Toggle(isOn: calendarBinding(cal.calendarIdentifier)) {
                                HStack(spacing: 6) {
                                    Circle().fill(Color(nsColor: cal.color)).frame(width: 9, height: 9)
                                    Text(cal.title)
                                    Text(cal.source.title).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Button { calendar.testKnock() } label: {
                            if let next = calendar.nextEventSummary {
                                Text("Test knock with my next event: \(next)")
                            } else {
                                Text("Test knock (no events in the next 24 h, uses a pretend meeting)")
                            }
                        }
                    }
                    if let calendarMessage {
                        Text(calendarMessage).font(.caption).foregroundStyle(.orange)
                    }
                    if calendar.isDenied {
                        Button("Open Privacy Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                        }
                    }
                    Text("Uses the calendars in macOS Calendar. To include Google Calendar, add your Google account in System Settings → Internet Accounts. All-day and declined events are skipped.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .character:
                Section("Active character") {
                    ActiveCharacterCard()
                }
                Section("Character") {
                    Picker("Comes in from the", selection: binding(\.entrySide)) {
                        Text("Left").tag(EntrySide.left)
                        Text("Right").tag(EntrySide.right)
                    }
                    .pickerStyle(.segmented)
                    Picker("Walks along the", selection: binding(\.verticalPosition)) {
                        Text("Bottom").tag(VerticalPosition.bottom)
                        Text("Top").tag(VerticalPosition.top)
                    }
                    .pickerStyle(.segmented)
                    Text("Use your own character by dropping transparent PNG frames into the Character folder: **walk_0.png, walk_1.png…**, **idle_0.png…**, **sip_0.png…**, **cheer_0.png…** and **knock_0.png…**. Draw them facing right; Sippy mirrors them when the character comes from the right. Add **appear.mp3** to play a sound when the character walks in, **cheer.mp3** for when you log a drink, and **knock.mp3** for meeting knocks. Leave the folder empty to use the built-in one.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Character Folder") {
                        let dir = AppPaths.characterDirectory
                        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(dir)
                    }
                }

                Section("Sound") {
                    if s.musicPaths.isEmpty {
                        Text("Music loops while the character is on screen for a water reminder. None yet.").foregroundStyle(.secondary)
                    }
                    ForEach(s.musicPaths, id: \.self) { path in
                        HStack {
                            Image(systemName: FileManager.default.fileExists(atPath: path) ? "music.note" : "exclamationmark.triangle")
                            Text((path as NSString).lastPathComponent).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button(role: .destructive) {
                                model.update { $0.musicPaths.removeAll { $0 == path } }
                            } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                        }
                    }
                    Button("Add music files…", action: pickMusic)
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: binding(\.volume), in: 0...1)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                    Toggle("Mute", isOn: binding(\.muted))
                }

            case .general:
                Section("General") {
                    Toggle("Show “Log Water” actions in Spotlight", isOn: binding(\.spotlightActions))
                    Text("Type “log water” in Spotlight (⌘Space) to log without opening Sippy. Logging resets the reminder countdown.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Open Sippy when I log in", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { on in setLaunchAtLogin(on) }
                    if let loginError {
                        Text(loginError).font(.caption).foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
    }

    /// Turning knocks on asks for Calendar access first.
    private var eventToggle: Binding<Bool> {
        Binding(
            get: { model.settings.eventRemindersEnabled && !calendar.isDenied },
            set: { on in
                guard on else {
                    model.update { $0.eventRemindersEnabled = false }
                    return
                }
                if calendar.isAuthorized {
                    calendarMessage = nil
                    model.update { $0.eventRemindersEnabled = true }
                    return
                }
                calendar.requestAccess { granted in
                    calendarMessage = granted ? nil : "Sippy needs Calendar access. Allow it in System Settings → Privacy & Security → Calendars."
                    model.update { $0.eventRemindersEnabled = granted }
                }
            }
        )
    }

    /// Per-calendar checkbox. An empty list means "all", so the first untick lists the rest explicitly.
    private func calendarBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { model.settings.eventCalendarIDs.isEmpty || model.settings.eventCalendarIDs.contains(id) },
            set: { on in
                model.update { s in
                    var ids = s.eventCalendarIDs.isEmpty ? calendar.calendars.map(\.calendarIdentifier) : s.eventCalendarIDs
                    if on { if !ids.contains(id) { ids.append(id) } } else { ids.removeAll { $0 == id } }
                    // Everything ticked again goes back to "all", so new calendars are included too;
                    // nothing ticked is stored as a marker, since an empty list means "all".
                    if ids.isEmpty {
                        s.eventCalendarIDs = ["none"]
                    } else {
                        s.eventCalendarIDs = Set(ids) == Set(calendar.calendars.map(\.calendarIdentifier))
                            ? [] : ids.filter { $0 != "none" }
                    }
                }
            }
        )
    }

    private var hoursSummary: String {
        let from = ActiveHours.clock(s.activeFromMinutes), to = ActiveHours.clock(s.activeToMinutes)
        if s.activeFromMinutes == s.activeToMinutes { return "Same start and end time means all day." }
        let overnight = s.activeFromMinutes > s.activeToMinutes ? " (overnight)" : ""
        return "Reminders only between \(from) and \(to)\(overnight). Outside these hours Sippy stays quiet; Remind Me Now still works."
    }

    /// Edits a minutes-after-midnight setting with a time picker.
    private func timeBinding(_ keyPath: WritableKeyPath<AppSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = model.settings[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.update { $0[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0) }
            }
        )
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { model.settings[keyPath: keyPath] },
                set: { value in model.update { $0[keyPath: keyPath] = value } })
    }

    private func pickMusic() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        panel.message = "Pick songs to play while the character is on screen"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        let picked = panel.urls.map(\.path)
        model.update { s in
            for p in picked where !s.musicPaths.contains(p) { s.musicPaths.append(p) }
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't change this: \(error.localizedDescription). Move Sippy to Applications and try again."
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// Shows which character Sippy will use: the user's frames from the Character folder, or the
/// built-in one. Lists each pose and sound, and what falls back when something is missing.
struct ActiveCharacterCard: View {
    @State private var sprites = SpriteSet()
    @State private var sounds: [String: Bool] = [:]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if let idle = sprites.frames(for: .idle)?.first {
                    Image(nsImage: idle).resizable().interpolation(.high).scaledToFit()
                } else {
                    DrawnCharacter(pose: .idle).scaleEffect(0.5).frame(width: 80, height: 115)
                }
            }
            .frame(width: 80, height: 120)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.08)))

            VStack(alignment: .leading, spacing: 6) {
                Text(sprites.isEmpty ? "Built-in character" : "Your custom character")
                    .font(.headline)
                if sprites.isEmpty {
                    Text("Drawn by Sippy. Add PNG frames to the Character folder to use your own.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    poseRow("Standing", sprites.idle.count, fallback: "—")
                    poseRow("Walking", sprites.walk.count, fallback: "standing frame")
                    poseRow("Sipping", sprites.sip.count, fallback: "standing frame")
                    poseRow("Cheering", sprites.cheer.count, fallback: "standing frame")
                    poseRow("Knocking", sprites.knock.count, fallback: "standing frame")
                }
                HStack(spacing: 10) {
                    soundTag("appear", "walk-in")
                    soundTag("cheer", "cheer")
                    soundTag("knock", "knock")
                }
                .padding(.top, 2)
                Button("Reload") { reload() }.controlSize(.small).padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .onAppear(perform: reload)
    }

    private func poseRow(_ name: String, _ count: Int, fallback: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: count > 0 ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(count > 0 ? .green : .secondary)
            Text(name)
            Text(count > 0 ? "\(count) frame\(count == 1 ? "" : "s")" : "uses \(fallback)")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func soundTag(_ file: String, _ label: String) -> some View {
        let has = sounds[file] ?? false
        // Knocking has a built-in sound; the others are silent without a file.
        let builtIn = file == "knock"
        let text = has ? "\(label) sound" : (builtIn ? "built-in knock" : "no \(label) sound")
        return Label(text, systemImage: has || builtIn ? "speaker.wave.2.fill" : "speaker.slash")
            .font(.caption2)
            .foregroundStyle(has ? .primary : .secondary)
    }

    private func reload() {
        sprites = SpriteSet.load()
        sounds = [
            "appear": AppPaths.appearSound != nil,
            "cheer": AppPaths.cheerSound != nil,
            "knock": AppPaths.knockSound != nil,
        ]
    }
}
