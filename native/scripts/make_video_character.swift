// Turns an ordinary video of a character (an AI image-to-video clip, a screen recording, a phone
// video) into a transparent HEVC clip Sippy can play, entirely on this Mac.
//
// Usage: swift scripts/make_video_character.swift <input video> <output.mov> [--green] [--height 620]
//        [--from 0.5] [--to 3.0]   keep only that part of the clip, in seconds
//
// The background is cut out with Apple's Vision subject detection (the "lift subject" from
// Photos), so any plain background works. Pass --green for a clip shot on a green screen: a
// colour key is faster and cleaner there. Name the output after the pose it shows (walk.mov,
// idle.mov, sip.mov, cheer.mov, knock.mov) and drop it in Sippy's Character folder.
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
import VideoToolbox

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("Usage: swift scripts/make_video_character.swift <input video> <output.mov> [--green] [--height 620] [--from s] [--to s]")
    exit(1)
}
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let greenScreen = args.contains("--green")
let maxHeight: CGFloat = args.firstIndex(of: "--height").flatMap { i in
    i + 1 < args.count ? Double(args[i + 1]).map { CGFloat($0) } : nil
} ?? 620

func seconds(after flag: String) -> Double? {
    args.firstIndex(of: flag).flatMap { i in i + 1 < args.count ? Double(args[i + 1]) : nil }
}
let trimFrom = seconds(after: "--from") ?? 0
let trimTo = seconds(after: "--to")

func fail(_ message: String) -> Never {
    print("✗ \(message)")
    exit(1)
}

// MARK: - Background removal

let context = CIContext(options: [.cacheIntermediates: false])

/// Vision finds the subject and returns a soft mask; everything else becomes transparent.
/// Green light bounced from a green screen tints the character's edges. Pulls green back to the
/// level of the other channels wherever it dominates; colours that aren't green-tinted are untouched.
let despill: CIFilter = {
    let size = 64
    var cube = [Float]()
    cube.reserveCapacity(size * size * size * 4)
    for b in 0..<size {
        for g in 0..<size {
            for r in 0..<size {
                let (rf, gf, bf) = (Float(r) / Float(size - 1), Float(g) / Float(size - 1), Float(b) / Float(size - 1))
                cube += [rf, min(gf, max(rf, bf)), bf, 1]
            }
        }
    }
    let filter = CIFilter.colorCubeWithColorSpace()
    filter.cubeDimension = Float(size)
    filter.cubeData = cube.withUnsafeBufferPointer { Data(buffer: $0) }
    filter.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
    return filter
}()

/// Set once the first frame shows a green background.
var removesGreenSpill = false

func source(_ frame: CVPixelBuffer) -> CIImage {
    let image = CIImage(cvPixelBuffer: frame)
    guard removesGreenSpill else { return image }
    despill.setValue(image, forKey: kCIInputImageKey)
    return despill.outputImage ?? image
}

func cutOutSubject(_ frame: CVPixelBuffer) -> CIImage? {
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cvPixelBuffer: frame)
    guard (try? handler.perform([request])) != nil, let result = request.results?.first,
          let mask = try? result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler) else {
        return nil
    }
    let blend = CIFilter.blendWithMask()
    blend.inputImage = source(frame)
    blend.backgroundImage = CIImage.empty()
    blend.maskImage = CIImage(cvPixelBuffer: mask)
    return blend.outputImage
}

/// A colour cube that makes green-screen greens transparent and keeps everything else.
let greenKey: CIFilter = {
    let size = 64
    var cube = [Float]()
    cube.reserveCapacity(size * size * size * 4)
    for b in 0..<size {
        for g in 0..<size {
            for r in 0..<size {
                let rgb = [Float(r), Float(g), Float(b)].map { $0 / Float(size - 1) }
                let maxC = rgb.max()!, minC = rgb.min()!
                let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
                // Green dominates both other channels clearly: background.
                let isGreen = rgb[1] > 0.25 && rgb[1] > rgb[0] * 1.3 && rgb[1] > rgb[2] * 1.3 && saturation > 0.3
                let alpha: Float = isGreen ? 0 : 1
                // Premultiplied: transparent pixels carry no colour, so no green fringe.
                cube += [rgb[0] * alpha, rgb[1] * alpha, rgb[2] * alpha, alpha]
            }
        }
    }
    let filter = CIFilter.colorCubeWithColorSpace()
    filter.cubeDimension = Float(size)
    filter.cubeData = cube.withUnsafeBufferPointer { Data(buffer: $0) }
    filter.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
    return filter
}()

func keyOutGreen(_ frame: CVPixelBuffer) -> CIImage? {
    greenKey.setValue(source(frame), forKey: kCIInputImageKey)
    return greenKey.outputImage
}

// MARK: - Read, cut out, write

let asset = AVURLAsset(url: input)
guard let track = try await asset.loadTracks(withMediaType: .video).first else { fail("No video track in \(input.path)") }
let (naturalSize, transform, fps) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
let shown = naturalSize.applying(transform)
let sourceSize = CGSize(width: abs(shown.width), height: abs(shown.height))
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func reader() throws -> (AVAssetReader, AVAssetReaderTrackOutput) {
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    ])
    output.alwaysCopiesSampleData = false
    reader.add(output)
    let end = trimTo.map { CMTime(seconds: $0, preferredTimescale: 600) } ?? .positiveInfinity
    reader.timeRange = CMTimeRange(start: CMTime(seconds: trimFrom, preferredTimescale: 600), end: end)
    guard reader.startReading() else { fail("Couldn't read \(input.lastPathComponent): \(reader.error?.localizedDescription ?? "unknown error")") }
    return (reader, output)
}

/// The cut-out frame, upright, with its lower-left corner at the origin.
func cutOut(_ frame: CVPixelBuffer) -> CIImage? {
    guard let cut = greenScreen ? keyOutGreen(frame) : cutOutSubject(frame) else { return nil }
    let upright = cut.transformed(by: transform)
    return upright.transformed(by: CGAffineTransform(translationX: -upright.extent.minX, y: -upright.extent.minY))
}

/// Where the character's pixels are in a frame, found on a quarter-size copy.
func opaqueBounds(_ image: CIImage) -> CGRect? {
    let shrink: CGFloat = 0.25
    let w = Int(sourceSize.width * shrink), h = Int(sourceSize.height * shrink)
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    context.render(image.transformed(by: CGAffineTransform(scaleX: shrink, y: shrink)), toBitmap: &pixels, rowBytes: w * 4,
                   bounds: CGRect(x: 0, y: 0, width: w, height: h), format: .RGBA8, colorSpace: srgb)
    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h {
        for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 60 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= 0 else { return nil }
    // Bitmap rows run top-down; Core Image's y runs bottom-up.
    return CGRect(x: CGFloat(minX) / shrink, y: CGFloat(h - 1 - maxY) / shrink,
                  width: CGFloat(maxX - minX + 1) / shrink, height: CGFloat(maxY - minY + 1) / shrink)
}

/// True when the frame's corners are clearly green: a green-screen clip.
func hasGreenBackground(_ frame: CVPixelBuffer) -> Bool {
    CVPixelBufferLockBaseAddress(frame, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(frame) else { return false }
    let row = CVPixelBufferGetBytesPerRow(frame), w = CVPixelBufferGetWidth(frame), h = CVPixelBufferGetHeight(frame)
    let px = base.assumingMemoryBound(to: UInt8.self)
    let corners = [(4, 4), (w - 5, 4), (4, h - 5), (w - 5, h - 5)]
    let green = corners.filter { x, y in
        let i = y * row + x * 4 // BGRA
        let (b, g, r) = (Double(px[i]), Double(px[i + 1]), Double(px[i + 2]))
        return g > 80 && g > r * 1.4 && g > b * 1.4
    }
    return green.count >= 3
}

// Some generators open on the still they started from, on a different background, so look a
// few frames in.
do {
    let (_, output) = try reader()
    for _ in 0..<12 {
        guard let sample = output.copyNextSampleBuffer() else { break }
        if let frame = CMSampleBufferGetImageBuffer(sample), hasGreenBackground(frame) {
            removesGreenSpill = true
            print("  green background: removing green spill from the edges")
            break
        }
    }
}

// Pass 1: find the box the character moves within, so a small character in a wide frame
// fills the clip. Every third frame is enough.
print("▸ \(input.lastPathComponent): \(Int(sourceSize.width))×\(Int(sourceSize.height)) at \(Int(fps.rounded())) fps, \(greenScreen ? "green-screen key" : "subject cut-out")")
var box = CGRect.null
do {
    let (_, output) = try reader()
    var i = 0
    while let sample = output.copyNextSampleBuffer() {
        defer { i += 1 }
        guard i % 3 == 0, let frame = CMSampleBufferGetImageBuffer(sample), let cut = cutOut(frame),
              let bounds = opaqueBounds(cut) else { continue }
        box = box.union(bounds)
    }
}
guard !box.isNull else { fail("Couldn't find a character in \(input.lastPathComponent)") }
// A little room around the character, less below so its feet stay on the floor.
let pad = box.height * 0.04
let crop = CGRect(x: box.minX - pad, y: box.minY - pad * 0.25, width: box.width + pad * 2, height: box.height + pad * 1.25)
    .intersection(CGRect(origin: .zero, size: sourceSize))
let scale = min(1, maxHeight / crop.height)
// HEVC wants even dimensions.
let outSize = CGSize(width: (crop.width * scale / 2).rounded() * 2, height: (crop.height * scale / 2).rounded() * 2)
print("  character fills \(Int(crop.width))×\(Int(crop.height)) → \(Int(outSize.width))×\(Int(outSize.height))")

// Pass 2: cut out, crop and encode every frame.
try? FileManager.default.removeItem(at: output)
let writer = try AVAssetWriter(outputURL: output, fileType: .mov)
let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
    AVVideoWidthKey: outSize.width,
    AVVideoHeightKey: outSize.height,
    AVVideoCompressionPropertiesKey: [
        AVVideoQualityKey: 0.75,
        kVTCompressionPropertyKey_TargetQualityForAlpha as String: 0.9,
    ],
])
writerInput.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: outSize.width,
    kCVPixelBufferHeightKey as String: outSize.height,
])
writer.add(writerInput)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

var frames = 0, misses = 0
var lastGood: CIImage?
let (_, trackOutput) = try reader()

while let sample = trackOutput.copyNextSampleBuffer() {
    guard let frame = CMSampleBufferGetImageBuffer(sample) else { continue }
    // Start the trimmed clip at zero.
    let time = CMSampleBufferGetPresentationTimeStamp(sample) - CMTime(seconds: trimFrom, preferredTimescale: 600)

    var cut = cutOut(frame)
    // Vision occasionally finds nothing in a blurry frame; reuse the last good one so it doesn't blink.
    if cut == nil { misses += 1; cut = lastGood }
    lastGood = cut
    guard let cut else { continue }
    let placed = cut
        .cropped(to: crop)
        .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
        .transformed(by: CGAffineTransform(scaleX: scale, y: scale))

    while !writerInput.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
    guard let pool = adaptor.pixelBufferPool else { fail("Writer has no buffer pool: \(writer.error?.localizedDescription ?? "")") }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    guard let buffer else { continue }
    context.render(placed, to: buffer, bounds: CGRect(origin: .zero, size: outSize), colorSpace: srgb)
    adaptor.append(buffer, withPresentationTime: time)
    frames += 1
    if frames % 60 == 0 { print("  \(frames) frames…") }
}

writerInput.markAsFinished()
await writer.finishWriting()
guard writer.status == .completed else { fail("Writing failed: \(writer.error?.localizedDescription ?? "unknown error")") }

let bytes = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
print("✓ \(output.lastPathComponent): \(frames) frames, \(bytes / 1024) KB\(misses > 0 ? " (\(misses) frames with no subject found, reused the previous one)" : "")")
