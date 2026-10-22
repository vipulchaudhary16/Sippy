import AVFoundation
import AppKit

/// Loops one of the user's music files while the character is on screen.
/// With no music configured the walk-in is silent.
final class AudioPlayer {
    private var player: AVAudioPlayer?

    func start(paths: [String], volume: Double, muted: Bool) {
        stop()
        guard !muted else { return }
        let playable = paths.filter { FileManager.default.fileExists(atPath: $0) }
        guard let path = playable.randomElement() else { return }
        // A missing or broken file just means no music, never a crash.
        guard let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) else { return }
        p.numberOfLoops = -1
        p.volume = 0
        p.play()
        p.setVolume(Float(volume), fadeDuration: 1.5)
        player = p
    }

    private var effect: AVAudioPlayer?

    /// One-shot sound (e.g. the cheer). Missing file or mute means silence.
    func playEffect(_ url: URL?, volume: Double, muted: Bool) {
        guard !muted, let url, let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.volume = Float(volume)
        p.play()
        effect = p
    }

    func apply(volume: Double, muted: Bool) {
        player?.volume = muted ? 0 : Float(volume)
    }

    func stop() {
        guard let p = player else { return }
        player = nil
        p.setVolume(0, fadeDuration: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { p.stop() }
    }
}
