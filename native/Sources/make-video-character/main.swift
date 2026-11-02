// Command-line version of Settings › Character › Video poses: turns any video of a character into
// a transparent clip Sippy can play.
//
// Usage: swift run make-video-character <input video> <output.mov> [--green] [--height 620]
//        [--from 0.5] [--to 3.0]
import Foundation
import SippyVideo

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("""
    Usage: swift run make-video-character <input video> <output.mov> [options]
      --green         colour-key a green screen instead of Vision's subject cut-out
      --height 620    output height in pixels
      --from 0.5      keep only from this second…
      --to 3.0        …to this one
    """)
    exit(1)
}

func value(after flag: String) -> Double? {
    args.firstIndex(of: flag).flatMap { i in i + 1 < args.count ? Double(args[i + 1]) : nil }
}

var options = VideoCharacterConverter.Options()
options.greenKey = args.contains("--green")
options.maxHeight = value(after: "--height").map { CGFloat($0) } ?? options.maxHeight
options.from = value(after: "--from") ?? 0
options.to = value(after: "--to")

let input = URL(fileURLWithPath: args[1]), output = URL(fileURLWithPath: args[2])
print("▸ \(input.lastPathComponent) → \(output.lastPathComponent)")
var shown = -1
do {
    let result = try await VideoCharacterConverter(input: input, options: options).convert(to: output) { p in
        let step = Int(p * 10)
        if step > shown { shown = step; print("  \(step * 10)%") }
    }
    print("✓ \(Int(result.size.width))×\(Int(result.size.height)), \(result.frames) frames, \(result.bytes / 1024) KB"
          + (result.removedGreenSpill ? ", green edges removed" : "")
          + (result.misses > 0 ? " (\(result.misses) frames reused)" : ""))
} catch {
    print("✗ \(error.localizedDescription)")
    exit(1)
}
