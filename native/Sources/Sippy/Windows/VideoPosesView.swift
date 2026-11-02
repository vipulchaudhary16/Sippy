import AVKit
import SippyCore
import SippyVideo
import SwiftUI
import UniformTypeIdentifiers

/// Settings › Character › Video poses: pick any video of the character for a pose; Sippy trims it,
/// cuts the background out and installs it as that pose's clip. No Terminal needed.
struct VideoPosesView: View {
    /// Called after a clip is added or removed, so previews can reload.
    var onChange: () -> Void = {}

    @State private var clips = SpriteSet.load().clips
    @State private var importing: ImportRequest?
    @State private var progress: [CharacterPose: Double] = [:]
    @State private var messages: [CharacterPose: String] = [:]

    struct Pose: Identifiable {
        let pose: CharacterPose
        let file: String
        let title: String
        let tip: String
        var id: String { file }
    }

    /// The pose and the file picked for it; the trim sheet is shown while this is set.
    struct ImportRequest: Identifiable {
        let pose: Pose
        let url: URL
        var id: String { pose.id }
    }

    static let poses = [
        Pose(pose: .idle, file: "idle", title: "Standing", tip: "breathing, blinking, looking around"),
        Pose(pose: .walking, file: "walk", title: "Walking", tip: "a walk cycle in place, facing right"),
        Pose(pose: .sipping, file: "sip", title: "Sipping", tip: "one sip from the bottle"),
        Pose(pose: .cheering, file: "cheer", title: "Cheering", tip: "a happy jump"),
        Pose(pose: .sad, file: "sad", title: "Sad", tip: "a disappointed sigh"),
        Pose(pose: .knocking, file: "knock", title: "Knocking", tip: "knock-knock on the screen"),
    ]

    var body: some View {
        ForEach(Self.poses) { pose in
            HStack {
                Image(systemName: clips[pose.pose] != nil ? "film.fill" : "film")
                    .foregroundStyle(clips[pose.pose] != nil ? Color.accentColor : .secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(pose.title)
                    Text(messages[pose.pose] ?? (clips[pose.pose] != nil ? "Video clip" : pose.tip))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let p = progress[pose.pose] {
                    ProgressView(value: p).frame(width: 90)
                } else {
                    if clips[pose.pose] != nil {
                        Button(role: .destructive) { remove(pose) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help("Remove this clip")
                    }
                    Button(clips[pose.pose] != nil ? "Replace…" : "Import video…") { pick(pose) }
                }
            }
        }
        .sheet(item: $importing) { request in
            VideoTrimSheet(url: request.url, title: request.pose.title) { from, to in
                importing = nil
                convert(request.url, for: request.pose, from: from, to: to)
            } onCancel: {
                importing = nil
            }
        }
    }

    private func pick(_ pose: Pose) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.message = "Pick a video of your character \(pose.tip)"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importing = ImportRequest(pose: pose, url: url)
    }

    private func convert(_ url: URL, for pose: Pose, from: Double, to: Double) {
        var options = VideoCharacterConverter.Options()
        options.from = from
        options.to = to
        let dir = AppPaths.characterDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let output = dir.appendingPathComponent("\(pose.file).mov")
        progress[pose.pose] = 0
        messages[pose.pose] = "Cutting out the background…"
        Task {
            do {
                let result = try await VideoCharacterConverter(input: url, options: options).convert(to: output) { p in
                    Task { @MainActor in progress[pose.pose] = p }
                }
                await MainActor.run {
                    progress[pose.pose] = nil
                    messages[pose.pose] = "Video clip · \(result.frames) frames, \(result.bytes / 1024) KB"
                    reload()
                }
            } catch {
                await MainActor.run {
                    progress[pose.pose] = nil
                    messages[pose.pose] = error.localizedDescription
                }
            }
        }
    }

    private func remove(_ pose: Pose) {
        if let url = clips[pose.pose] { try? FileManager.default.removeItem(at: url) }
        messages[pose.pose] = nil
        reload()
    }

    private func reload() {
        clips = SpriteSet.load().clips
        onChange()
    }
}

/// Watch the video and choose the part to keep: one sip, one jump, a loop that starts and ends
/// in the same pose.
private struct VideoTrimSheet: View {
    let url: URL
    let title: String
    let onConvert: (Double, Double) -> Void
    let onCancel: () -> Void

    @State private var player = AVPlayer()
    @State private var duration: Double = 0
    @State private var from: Double = 0
    @State private var to: Double = 0
    @State private var loopObserver: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(title) clip").font(.headline)
            PlayerPreview(player: player)
                .frame(width: 420, height: 300)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if duration > 0 {
                trimSlider("Start", value: $from, range: 0...max(to - 0.2, 0.01))
                trimSlider("End", value: $to, range: min(from + 0.2, duration)...duration)
                Text("Keeps \(String(format: "%.1f", to - from)) s. Short clips that start and end in the same pose loop best.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }

            HStack {
                Text("The background is removed on your Mac; nothing is uploaded.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Use this clip") { player.pause(); onConvert(from, to) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(duration == 0)
            }
        }
        .padding(20)
        .frame(width: 460)
        .task {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            player.isMuted = true
            let seconds = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
            duration = seconds
            to = seconds
            // Loop the kept part while choosing.
            loopObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { time in
                if time.seconds >= to || time.seconds < from - 0.05 { seek(from) }
            }
            player.play()
        }
        .onDisappear {
            player.pause()
            if let loopObserver { player.removeTimeObserver(loopObserver) }
        }
    }

    private func trimSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(label).frame(width: 40, alignment: .leading)
            Slider(value: value, in: range) { editing in
                if !editing { seek(from) }
            }
            .onChange(of: value.wrappedValue) { seek($0) }
            Text(String(format: "%.1f s", value.wrappedValue)).monospacedDigit().frame(width: 50, alignment: .trailing)
        }
    }

    private func seek(_ seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

/// AVKit's player view without controls: the sliders below do the trimming. Using AVPlayerView
/// directly (rather than SwiftUI's VideoPlayer) also makes the build link AVKit itself, which
/// VideoPlayer needs at run time.
private struct PlayerPreview: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = player
    }
}
