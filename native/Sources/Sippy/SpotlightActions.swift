import AppKit
import SippyCore

/// Keeps tiny "Log Water – …" launcher apps in ~/Applications/Sippy Actions so typing
/// "log water" in Spotlight offers them. Each launcher just opens `sippy://log?amount=…`.
/// (Real App Shortcuts need Xcode's App Intents metadata step, which the Command Line Tools lack.)
enum SpotlightActions {
    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/Sippy Actions", isDirectory: true)
    }

    /// Rebuilds the launchers for the current settings, or removes them when turned off.
    static func sync(_ settings: AppSettings) {
        let fm = FileManager.default
        try? fm.removeItem(at: folder)
        guard settings.spotlightActions else { return }
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for action in Amounts(settings).spotlightActions {
            makeLauncher(title: action.title, amount: action.amount)
        }
        // Spotlight would get to the new folder eventually; ask it to index now.
        let index = Process()
        index.executableURL = URL(fileURLWithPath: "/usr/bin/mdimport")
        index.arguments = [folder.path]
        try? index.run()
    }

    private static func makeLauncher(title: String, amount: String) {
        let fm = FileManager.default
        let app = folder.appendingPathComponent("\(title).app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents")
        let macOS = contents.appendingPathComponent("MacOS")
        let resources = contents.appendingPathComponent("Resources")
        try? fm.createDirectory(at: macOS, withIntermediateDirectories: true)
        try? fm.createDirectory(at: resources, withIntermediateDirectories: true)

        let script = """
        #!/bin/sh
        exec /usr/bin/open -g "sippy://log?amount=\(amount)"
        """
        let exe = macOS.appendingPathComponent("log")
        try? script.write(to: exe, atomically: true, encoding: .utf8)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exe.path)

        var plist: [String: Any] = [
            "CFBundleName": title,
            "CFBundleDisplayName": title,
            "CFBundleIdentifier": "com.vipulchaudhary.sippy.action.\(amount)",
            "CFBundleExecutable": "log",
            "CFBundlePackageType": "APPL",
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": "13.0",
            "LSUIElement": true,
        ]
        if let icon = Bundle.main.url(forResource: "Sippy", withExtension: "icns") {
            try? fm.copyItem(at: icon, to: resources.appendingPathComponent("Sippy.icns"))
            plist["CFBundleIconFile"] = "Sippy"
        }
        (plist as NSDictionary).write(to: contents.appendingPathComponent("Info.plist"), atomically: true)

        // Let Launch Services and Spotlight know about it right away.
        LSRegisterURL(app as CFURL, true)
    }
}
