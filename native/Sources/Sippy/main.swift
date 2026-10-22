import AppKit

// Dev aid: `Sippy --render-previews <dir>` writes PNGs of each overlay pose and exits.
if let i = CommandLine.arguments.firstIndex(of: "--render-previews"), i + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated { renderPreviews(to: URL(fileURLWithPath: CommandLine.arguments[i + 1])) }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu-bar only: no Dock icon, keeps running in the background.
app.setActivationPolicy(.accessory)
app.run()
