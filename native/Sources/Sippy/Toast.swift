import AppKit
import SwiftUI

/// A small "Logged 250 ml" pill under the menu bar, for logs that happen without a window open
/// (Spotlight actions, sippy:// links, the menu).
final class Toast {
    private var panel: NSPanel?
    private var hide: DispatchWorkItem?

    func show(_ text: String) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let view = NSHostingView(rootView: ToastView(text: text))
        let size = view.fittingSize
        let frame = NSRect(x: screen.visibleFrame.midX - size.width / 2,
                           y: screen.visibleFrame.maxY - size.height - 12,
                           width: size.width, height: size.height)

        let p = panel ?? {
            let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.level = .statusBar
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            p.ignoresMouseEvents = true
            panel = p
            return p
        }()
        p.contentView = view
        p.setFrame(frame, display: true)
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.2; p.animator().alphaValue = 1 }

        hide?.cancel()
        let work = DispatchWorkItem { [weak p] in
            guard let p else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.4; p.animator().alphaValue = 0 },
                                                 completionHandler: { p.orderOut(nil) })
        }
        hide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }
}

private struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "drop.fill").foregroundStyle(.blue)
            Text(text).font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .padding(8)
    }
}
