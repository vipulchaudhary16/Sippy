// Checks custom character frames before you use them: size, transparency, and alignment.
// Usage: swift scripts/check_frames.swift [folder]   (default: Sippy's Character folder)
import AppKit

let folder = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Sippy/Character")

let files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

guard !files.isEmpty else {
    print("No PNG frames in \(folder.path)")
    exit(1)
}

struct Frame {
    let name: String
    let width: Int, height: Int
    let clear: Double, partial: Double
    let top: Int, feet: Int, left: Int, right: Int
}

func analyse(_ url: URL) -> Frame? {
    guard let data = try? Data(contentsOf: url), let rep = NSBitmapImageRep(data: data) else { return nil }
    var clear = 0, partial = 0, total = 0
    var minX = Int.max, minY = Int.max, maxX = 0, maxY = 0
    for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
        for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
            let a = rep.colorAt(x: x, y: y)?.alphaComponent ?? 1
            total += 1
            if a < 0.02 { clear += 1 } else if a < 0.98 { partial += 1 }
            if a > 0.5 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
        }
    }
    return Frame(name: url.lastPathComponent, width: rep.pixelsWide, height: rep.pixelsHigh,
                 clear: Double(clear) / Double(total), partial: Double(partial) / Double(total),
                 top: minY, feet: maxY, left: minX, right: maxX)
}

let frames = files.compactMap(analyse)
let reference = frames.first { $0.name.hasPrefix("idle_0") } ?? frames[0]
let validName = try! NSRegularExpression(pattern: "^(idle|walk|sip|cheer)_[0-9]+\\.png$")
var problems = 0

print("Reference: \(reference.name) (\(reference.width)x\(reference.height), feet at y=\(reference.feet))\n")
for f in frames {
    var notes: [String] = []
    let range = NSRange(f.name.startIndex..., in: f.name)
    if validName.firstMatch(in: f.name, range: range) == nil { notes.append("name should be idle_N / walk_N / sip_N / cheer_N .png") }
    if f.width != reference.width || f.height != reference.height { notes.append("canvas \(f.width)x\(f.height) differs from reference") }
    if f.clear < 0.2 { notes.append("background doesn't look transparent (\(Int(f.clear * 100))% clear)") }
    if f.partial > 0.1 { notes.append("lots of semi-transparent pixels (\(Int(f.partial * 100))%), may show a halo") }
    let drift = f.feet - reference.feet
    // Cheer frames may hop; everything else should stand on the same line.
    if abs(drift) > 12 && !f.name.hasPrefix("cheer") { notes.append("feet \(abs(drift))px \(drift < 0 ? "higher" : "lower") than reference, will jump") }
    let mark = notes.isEmpty ? "✓" : "⚠︎"
    if !notes.isEmpty { problems += 1 }
    print("\(mark) \(f.name)  feet y=\(f.feet)  body x \(f.left)-\(f.right)  \(Int(f.clear * 100))% clear")
    notes.forEach { print("    - \($0)") }
}
print(problems == 0 ? "\nAll frames look good." : "\n\(problems) frame(s) need a look.")
