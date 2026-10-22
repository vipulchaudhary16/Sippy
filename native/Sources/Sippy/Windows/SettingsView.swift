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
            Section("Reminders") {
                Stepper("Remind me every **\(s.intervalMinutes) min**",
                        value: binding(\.intervalMinutes), in: 1...240, step: s.intervalMinutes < 10 ? 1 : 5)
                Stepper("Snooze for **\(s.snoozeMinutes) min**", value: binding(\.snoozeMinutes), in: 1...120)
                Stepper("Daily goal: **\(s.dailyGoal) glasses**", value: binding(\.dailyGoal), in: 1...30)
                Stepper("If I don't answer, snooze after **\(s.autoSnoozeMinutes) min**",
                        value: binding(\.autoSnoozeMinutes), in: 1...30)
                Button("Show the reminder now") { model.remindNow() }
            }

            Section("Music") {
                if s.musicPaths.isEmpty {
                    Text("No music yet, so she walks in quietly.").foregroundStyle(.secondary)
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
                Text("Use your own character by dropping transparent PNG frames into the Character folder: **walk_0.png, walk_1.png…**, **idle_0.png…**, **sip_0.png…**, and optionally **cheer_0.png…**. Draw them facing right. Add **cheer.mp3** to play a sound when you log a glass. Leave the folder empty to use the built-in one.")
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
