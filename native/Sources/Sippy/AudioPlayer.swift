import AVFoundation
import AppKit
import SippyCore

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

    /// The user's knock.mp3, or a generated "knock-knock, knock-knock" on wood.
    func playKnock(volume: Double, muted: Bool) {
        guard !muted else { return }
        let p = AppPaths.knockSound.flatMap { try? AVAudioPlayer(contentsOf: $0) }
            ?? (try? AVAudioPlayer(data: Self.knockWAV))
        guard let p else { return }
        p.volume = Float(volume)
        p.play()
        effect = p
    }

    /// Four short, damped low thuds with a click of noise, as 16-bit mono WAV.
    static let knockWAV: Data = {
        let rate = 44_100.0
        let hits = [0.0, 0.17, 0.62, 0.79]
        var samples = [Double](repeating: 0, count: Int(rate * 1.1))
        for hit in hits {
            let start = Int(hit * rate)
            for i in 0..<Int(0.1 * rate) where start + i < samples.count {
                let t = Double(i) / rate
                let body = 0.6 * sin(2 * .pi * 150 * t) + 0.3 * sin(2 * .pi * 330 * t)
                let click = 0.3 * Double.random(in: -1...1) * exp(-t * 220)
                samples[start + i] += (body * exp(-t * 55) + click)
            }
        }
        var pcm = Data()
        for s in samples {
            var v = Int16(max(-1, min(1, s)) * 26_000).littleEndian
            pcm.append(Data(bytes: &v, count: 2))
        }
        func le<T: FixedWidthInteger>(_ x: T) -> Data { var v = x.littleEndian; return Data(bytes: &v, count: MemoryLayout<T>.size) }
        var wav = Data("RIFF".utf8)
        wav += le(UInt32(36 + pcm.count)) + Data("WAVEfmt ".utf8)
        wav += le(UInt32(16)) + le(UInt16(1)) + le(UInt16(1)) + le(UInt32(44_100)) + le(UInt32(88_200))
        wav += le(UInt16(2)) + le(UInt16(16)) + Data("data".utf8) + le(UInt32(pcm.count)) + pcm
        return wav
    }()

    func apply(volume: Double, muted: Bool) {
        player?.volume = muted ? 0 : Float(volume)
    }

    /// Fades out the music and any one-shot still playing (e.g. the walk-in sound).
    func stop() {
        for p in [player, effect].compactMap({ $0 }) {
            p.setVolume(0, fadeDuration: 0.6)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { p.stop() }
        }
        player = nil
        effect = nil
    }
}
