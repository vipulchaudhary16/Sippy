import AppKit
import ServiceManagement
import SwiftUI
import SippyCore
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    private var s: AppSettings { model.settings }

    var body: some View {
        Form {
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

            Section("Reminder hours") {
                Toggle("Only remind me during set hours", isOn: binding(\.activeHoursEnabled))
                if s.activeHoursEnabled {
                    DatePicker("From", selection: timeBinding(\.activeFromMinutes), displayedComponents: .hourAndMinute)
                    DatePicker("To", selection: timeBinding(\.activeToMinutes), displayedComponents: .hourAndMinute)
                    Text(hoursSummary)
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

            Section("Music") {
                if s.musicPaths.isEmpty {
                    Text("No music yet, so the character walks in quietly.").foregroundStyle(.secondary)
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
                Text("Use your own character by dropping transparent PNG frames into the Character folder: **walk_0.png, walk_1.png…**, **idle_0.png…**, **sip_0.png…**, and optionally **cheer_0.png…**. Draw them facing right; Sippy mirrors them when the character comes from the right. Add **appear.mp3** to play a sound when the character walks in, and **cheer.mp3** for when you log a drink. Leave the folder empty to use the built-in one.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Character Folder") {
                    let dir = AppPaths.characterDirectory
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(dir)
                }
            }

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
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 520)
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
