import AppKit
import SwiftUI
import SippyCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var windows: [String: NSWindow] = [:]

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
        menu.autoenablesItems = false
        fill(menu)
        return menu
    }

    /// The menu is rebuilt each time it opens so progress, timers and meetings are current.
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        fill(menu)
    }

    private func fill(_ menu: NSMenu) {
        // Water
        menu.addItem(header("Water"))
        menu.addItem(info("\(model.amounts.progress(model.todayML)) today", symbol: "drop.fill"))
        menu.addItem(info(waterStatus, symbol: model.paused ? "pause.circle" : "clock"))
        menu.addItem(item(model.amounts.quickLog.label, #selector(logQuick), "l"))
        menu.addItem(item("Remind Me Now", #selector(remindNow), "r"))
        let pause = item("Pause Water Reminders", #selector(togglePause), "p")
        pause.state = model.paused ? .on : .off
        menu.addItem(pause)

        // Meetings
        menu.addItem(.separator())
        menu.addItem(header("Meetings"))
        if !model.settings.eventRemindersEnabled || !model.calendar.isAuthorized {
            menu.addItem(item("Set Up Meeting Knocks…", #selector(openMeetingSettings), ""))
        } else {
            let today = model.calendar.upcomingToday(limit: 4)
            if today.isEmpty {
                menu.addItem(info("No more meetings today", symbol: "calendar"))
            }
            for event in today {
                menu.addItem(meetingItem(event))
            }
            menu.addItem(info("Knocks \(model.settings.eventLeadMinutes) min before", symbol: "bell"))
        }

        menu.addItem(.separator())
        menu.addItem(item("Dashboard…", #selector(openDashboard), "d"))
        menu.addItem(item("Settings…", #selector(openSettings), ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit Sippy", #selector(quit), "q"))
    }

    private var waterStatus: String {
        if model.paused { return "Reminders paused" }
        guard let next = model.scheduler.nextFire else { return "Reminder on screen" }
        let mins = max(0, Int(ceil(next.timeIntervalSinceNow / 60)))
        if mins <= 1 { return "Next reminder in under a minute" }
        if mins <= 90 { return "Next reminder in \(mins) min" }
        // Far off, usually waiting for reminder hours to open: show the clock time.
        let time = next.formatted(date: .omitted, time: .shortened)
        let day = Calendar.current.isDateInToday(next) ? "" : (Calendar.current.isDateInTomorrow(next) ? " tomorrow" : "")
        return "Next reminder at \(time)\(day)"
    }

    /// "3:30 PM  Design review", clickable to join when the meeting has a link.
    private func meetingItem(_ event: UpcomingEvent) -> NSMenuItem {
        let now = Date()
        let time = event.start <= now ? "Now" : event.start.formatted(date: .omitted, time: .shortened)
        let title = "\(time)  \(event.title.isEmpty ? "Event" : event.title)"
        guard let link = event.meetingLink else {
            return info(title, symbol: "calendar")
        }
        let i = item(title, #selector(joinMeeting(_:)), "")
        i.representedObject = link
        i.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Join")
        i.toolTip = "Join \(link.host ?? "meeting")"
        return i
    }

    private func header(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return NSMenuItem.sectionHeader(title: title) }
        let i = NSMenuItem(title: title.uppercased(), action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    /// A non-clickable status line with an icon.
    private func info(_ title: String, symbol: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        i.isEnabled = false
        return i
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func remindNow() { model.remindNow() }
    @objc private func logQuick() { model.logFromAnywhere(ml: model.amounts.quickLog.ml) }
    @objc private func togglePause() { model.paused.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func joinMeeting(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { NSWorkspace.shared.open(url) }
    }

    @objc private func openDashboard() {
        present("dashboard", title: "Sippy", size: NSSize(width: 560, height: 680),
                view: DashboardView(model: model))
    }

    @objc private func openSettings() { showSettings(nil) }
    @objc private func openMeetingSettings() { showSettings(.meetings) }

    /// Settings with toolbar tabs (Water, Meetings, Character, General), like a standard Mac preferences window.
    private func showSettings(_ tab: SettingsTab?) {
        let window = windows["settings"] ?? {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            for t in SettingsTab.allCases {
                let item = NSTabViewItem(viewController: NSHostingController(rootView: SettingsView(model: model, tab: t)))
                item.label = t.title
                item.image = NSImage(systemSymbolName: t.symbol, accessibilityDescription: t.title)
                item.identifier = t.rawValue
                tabs.addTabViewItem(item)
            }
            let w = NSWindow(contentViewController: tabs)
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            windows["settings"] = w
            return w
        }()
        if let tab, let tabs = window.contentViewController as? NSTabViewController,
           let index = SettingsTab.allCases.firstIndex(of: tab) {
            tabs.selectedTabViewItemIndex = index
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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
