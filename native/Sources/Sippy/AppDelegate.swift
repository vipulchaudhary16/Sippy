import AppKit
import SwiftUI
import SippyCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var windows: [String: NSWindow] = [:]

    private let todayItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let nextItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private lazy var logItem = NSMenuItem(title: "Log a Glass", action: #selector(logQuick), keyEquivalent: "l")
    private lazy var pauseItem = NSMenuItem(title: "Pause Reminders", action: #selector(togglePause), keyEquivalent: "p")

    /// sippy:// links (Spotlight actions, Shortcuts, Raycast…). Also called when a link launches the app.
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(model.handle(url:))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.glassIcon()
        statusItem.menu = buildMenu()

        model.start()

        let firstLaunchKey = "sippy.hasLaunched"
        if !UserDefaults.standard.bool(forKey: firstLaunchKey) {
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            // Say hi so the user meets the character right away.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.model.remindNow() }
        }
    }

    /// Menu-bar glass: a tapered tumbler, half full. Template so it follows light/dark menu bars.
    static func glassIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let top: CGFloat = 16, bottom: CGFloat = 2, topHalf: CGFloat = 6.5, bottomHalf: CGFloat = 4.8, mid: CGFloat = 9
            func x(_ y: CGFloat, _ side: CGFloat) -> CGFloat {
                let half = bottomHalf + (topHalf - bottomHalf) * (y - bottom) / (top - bottom)
                return mid + side * half
            }
            let outline = NSBezierPath()
            outline.move(to: NSPoint(x: x(top, -1), y: top))
            outline.line(to: NSPoint(x: x(bottom, -1), y: bottom))
            outline.line(to: NSPoint(x: x(bottom, 1), y: bottom))
            outline.line(to: NSPoint(x: x(top, 1), y: top))
            outline.lineWidth = 1.5
            outline.lineJoinStyle = .round
            outline.lineCapStyle = .round
            NSColor.black.setStroke()
            outline.stroke()

            let level: CGFloat = 9.5
            let water = NSBezierPath()
            water.move(to: NSPoint(x: x(bottom, -1) + 1, y: bottom + 1))
            water.line(to: NSPoint(x: x(level, -1) + 1, y: level))
            water.curve(to: NSPoint(x: x(level, 1) - 1, y: level),
                        controlPoint1: NSPoint(x: mid - 1.5, y: level + 1.4),
                        controlPoint2: NSPoint(x: mid + 1.5, y: level - 1.4))
            water.line(to: NSPoint(x: x(bottom, 1) - 1, y: bottom + 1))
            water.close()
            NSColor.black.setFill()
            water.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Sippy"
        return image
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
        logItem.target = self
        menu.addItem(logItem)
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
        todayItem.title = "💧 Today: \(model.amounts.progress(model.todayML))"
        logItem.title = model.amounts.quickLog.label
        pauseItem.state = model.paused ? .on : .off
        if model.paused {
            nextItem.title = "Reminders paused"
        } else if let next = model.scheduler.nextFire {
            let mins = max(0, Int(ceil(next.timeIntervalSinceNow / 60)))
            if mins <= 1 {
                nextItem.title = "Next reminder in under a minute"
            } else if mins <= 90 {
                nextItem.title = "Next reminder in \(mins) min"
            } else {
                // Far off, usually waiting for reminder hours to open: show the clock time.
                let time = next.formatted(date: .omitted, time: .shortened)
                let day = Calendar.current.isDateInToday(next) ? "" : (Calendar.current.isDateInTomorrow(next) ? " tomorrow" : "")
                nextItem.title = "Next reminder at \(time)\(day)"
            }
        } else {
            nextItem.title = "Reminder on screen"
        }
    }

    @objc private func remindNow() { model.remindNow() }
    @objc private func logQuick() { model.logFromAnywhere(ml: model.amounts.quickLog.ml) }
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
