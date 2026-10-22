import AppKit
import SwiftUI
import SippyCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var windows: [String: NSWindow] = [:]

    private let todayItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let nextItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private lazy var pauseItem = NSMenuItem(title: "Pause Reminders", action: #selector(togglePause), keyEquivalent: "p")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Sippy")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.menu = buildMenu()

        model.start()

        let firstLaunchKey = "sippy.hasLaunched"
        if !UserDefaults.standard.bool(forKey: firstLaunchKey) {
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            // Say hi so the user meets the character right away.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.model.remindNow() }
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        todayItem.isEnabled = false
        nextItem.isEnabled = false
        menu.addItem(todayItem)
        menu.addItem(nextItem)
        menu.addItem(.separator())
        menu.addItem(item("Remind Me Now", #selector(remindNow), "r"))
        menu.addItem(item("Log a Glass", #selector(logGlass), "l"))
        pauseItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        menu.addItem(item("Dashboard…", #selector(openDashboard), "d"))
        menu.addItem(item("Settings…", #selector(openSettings), ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit Sippy", #selector(quit), "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    func menuWillOpen(_ menu: NSMenu) {
        todayItem.title = "💧 Today: \(model.todayCount) of \(model.settings.dailyGoal) glasses"
        pauseItem.state = model.paused ? .on : .off
        if model.paused {
            nextItem.title = "Reminders paused"
        } else if let next = model.scheduler.nextFire {
            let mins = max(0, Int(ceil(next.timeIntervalSinceNow / 60)))
            nextItem.title = mins <= 1 ? "Next reminder in under a minute" : "Next reminder in \(mins) min"
        } else {
            nextItem.title = "Reminder on screen"
        }
    }

    @objc private func remindNow() { model.remindNow() }
    @objc private func logGlass() { model.logGlass() }
    @objc private func togglePause() { model.paused.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openDashboard() {
        present("dashboard", title: "Sippy", size: NSSize(width: 520, height: 600),
                view: DashboardView(model: model))
    }

    @objc private func openSettings() {
        present("settings", title: "Sippy Settings", size: NSSize(width: 480, height: 620),
                view: SettingsView(model: model))
    }

    private func present<V: View>(_ key: String, title: String, size: NSSize, view: V) {
        let window = windows[key] ?? {
            let w = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
            w.title = title
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: view)
            w.center()
            windows[key] = w
            return w
        }()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
