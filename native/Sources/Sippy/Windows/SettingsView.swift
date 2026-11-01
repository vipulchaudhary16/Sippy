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
                    Toggle("Pause while I'm away from the Mac", isOn: binding(\.pauseWhenIdle))
                    if s.pauseWhenIdle {
                        Stepper("Away after **\(s.idleMinutes) min** without mouse or keyboard",
                                value: binding(\.idleMinutes), in: 1...60)
                    }
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
                    if calendar.needsAccess {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("Sippy needs permission to read your calendar.")
                            Spacer()
                            Button("Allow Calendar Access") { askForCalendar() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
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
                    }
                    if s.eventRemindersEnabled {
                        Button { calendar.testKnock() } label: {
                            if let next = calendar.nextEventSummary {
                                Label("Test knock with my next event: \(next)", systemImage: "play.circle.fill")
                            } else {
                                Label("Test knock (no upcoming events, uses a pretend meeting)", systemImage: "play.circle.fill")
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
                    ActiveCharacterCard(model: model)
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
                    Picker("Arrives by", selection: binding(\.entranceStyle)) {
                        Text("Walking in").tag(EntranceStyle.walk)
                        Text("Dropping in").tag(EntranceStyle.drop)
                        Text("Surprise me").tag(EntranceStyle.surprise)
                    }
                    .pickerStyle(.segmented)
                    .disabled(s.verticalPosition == .top)
                    Text("Use your own character by dropping transparent PNG frames into the Character folder: **walk_0.png, walk_1.png…**, **idle_0.png…**, **sip_0.png…**, **cheer_0.png…**, **sad_0.png…** and **knock_0.png…**. Draw them facing right; Sippy mirrors them when the character comes from the right. Add **appear.mp3** to play a sound when the character walks in, **cheer.mp3** for when you log a drink, and **knock.mp3** for meeting knocks. Leave the folder empty to use the built-in one.")
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

                Section("Sound effects") {
                    ForEach(SoundEffect.allCases, id: \.self) { sound in
                        SoundEffectRow(sound: sound, model: model)
                    }
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

    private func askForCalendar() {
        calendar.requestAccess { granted in
            calendarMessage = granted ? nil : "Calendar access wasn't allowed. Turn it on in System Settings → Privacy & Security → Calendars."
        }
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
/// built-in one. Click the picture to play each pose; click a sound to hear it.
struct ActiveCharacterCard: View {
    let model: AppModel
    @State private var sprites = SpriteSet()
    @State private var poseIndex = 0

    private let poses: [(CharacterPose, String)] = [
        (.idle, "Standing"), (.walking, "Walking"), (.sipping, "Sipping"), (.cheering, "Cheering"), (.sad, "Sad"), (.knocking, "Knocking"),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 4) {
                CharacterView(pose: poses[poseIndex].0, sprites: sprites)
                    .frame(width: 210, height: 310)
                    .scaleEffect(0.42)
                    .frame(width: 90, height: 132)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.08)))
                    .contentShape(Rectangle())
                    .onTapGesture { poseIndex = (poseIndex + 1) % poses.count }
                    .help("Click to see the next pose")
                Text("\(poses[poseIndex].1) ›")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(sprites.isEmpty ? "Built-in character" : "Your custom character")
                    .font(.headline)
                if sprites.isEmpty {
                    Text("Drawn by Sippy. Add PNG frames or video clips to the Character folder to use your own.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    poseRow("Standing", sprites.idle.count, video: sprites.clips[.idle] != nil, fallback: "—")
                    poseRow("Walking", sprites.walk.count, video: sprites.clips[.walking] != nil, fallback: "standing frame")
                    poseRow("Sipping", sprites.sip.count, video: sprites.clips[.sipping] != nil, fallback: "standing frame")
                    poseRow("Cheering", sprites.cheer.count, video: sprites.clips[.cheering] != nil, fallback: "standing frame")
                    poseRow("Sad", sprites.sad.count, video: sprites.clips[.sad] != nil, fallback: "standing frame")
                    poseRow("Knocking", sprites.knock.count, video: sprites.clips[.knocking] != nil, fallback: "standing frame")
                }
                HStack(spacing: 8) {
                    soundButton(.appear)
                    soundButton(.cheer)
                    soundButton(.knock)
                }
                .padding(.top, 2)
                Button("Reload") { reload() }.controlSize(.small).padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .onAppear(perform: reload)
    }

    private func poseRow(_ name: String, _ count: Int, video: Bool, fallback: String) -> some View {
        let has = video || count > 0
        return HStack(spacing: 6) {
            Image(systemName: has ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(has ? .green : .secondary)
            Text(name)
            Text(video ? "video clip" : count > 0 ? "\(count) frame\(count == 1 ? "" : "s")" : "uses \(fallback)")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    /// Plays the sound at the current volume, even when muted, since this is a test.
    private func soundButton(_ sound: SoundEffect) -> some View {
        let settings = model.settings
        let playable = sound.url(in: settings) != nil || (sound == .knock && sound.choice(in: settings) == .standard)
        return Button {
            model.audio.play(sound, settings: model.settings, test: true)
        } label: {
            Label(sound.title, systemImage: playable ? "play.circle.fill" : "speaker.slash")
        }
        .controlSize(.small)
        .disabled(!playable)
        .help(playable ? "Play the \(sound.title.lowercased()) sound" : "Pick a sound in Settings › Sound")
    }

    private func reload() {
        sprites = SpriteSet.load()
    }
}

/// One sound effect: what plays, a menu to change it (your file, a macOS sound, or none), and a
/// preview button.
struct SoundEffectRow: View {
    let sound: SoundEffect
    @ObservedObject var model: AppModel
    @State private var error: String?
    /// Bumped after copying or removing a file, so the row re-reads the Character folder.
    @State private var revision = 0

    private var choice: SoundEffect.Choice { sound.choice(in: model.settings) }

    private var currentName: String {
        _ = revision
        switch choice {
        case .none: return "None"
        case .system(let name): return name
        case .standard:
            if let file = sound.customFile { return file.lastPathComponent }
            return sound == .knock ? "Built-in knock" : "None"
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(sound.title)
                Text(error ?? sound.detail).font(.caption).foregroundStyle(error == nil ? Color.secondary : Color.red)
            }
            Spacer()
            Menu(currentName) {
                if let file = sound.customFile {
                    Button("My file: \(file.lastPathComponent)") { set(.standard) }
                } else if sound == .knock {
                    Button("Built-in knock") { set(.standard) }
                }
                Button("None") { set(.none) }
                Divider()
                ForEach(SoundEffect.systemSounds, id: \.self) { name in
                    Button(name) {
                        set(.system(name))
                        model.audio.play(sound, settings: model.settings, test: true)
                    }
                }
                Divider()
                Button("Choose a file…", action: chooseFile)
                if sound.customFile != nil {
                    Button("Remove my file", role: .destructive) {
                        try? sound.removeCustomFile()
                        if choice == .standard { set(.standard) }
                        revision += 1
                    }
                }
            }
            .fixedSize()
            Button {
                model.audio.play(sound, settings: model.settings, test: true)
            } label: {
                Image(systemName: "play.circle.fill")
            }
            .buttonStyle(.borderless)
            .help("Play")
        }
    }

    private func set(_ choice: SoundEffect.Choice) {
        model.update { $0.soundChoices[sound.rawValue] = choice.stored }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.message = "Pick a sound for “\(sound.title)” (\(sound.detail))"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try sound.install(url)
            error = nil
            set(.standard)
            revision += 1
            model.audio.play(sound, settings: model.settings, test: true)
        } catch {
            self.error = "Couldn't copy that file: \(error.localizedDescription)"
        }
    }
}
