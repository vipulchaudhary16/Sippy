import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import VideoToolbox
import Vision

/// Turns an ordinary video of a character (an AI image-to-video clip, a phone video) into a
/// transparent HEVC clip Sippy can play, entirely on this Mac.
///
/// The background is cut out with Apple's Vision subject detection, so any plain background
/// works; on a green screen the green tint bounced onto the character's edges is removed too.
/// The clip is cropped to the area the character moves within, so a small character in a wide
/// frame still fills it, and scaled to `maxHeight`.
public final class VideoCharacterConverter {
    public struct Options {
        /// Output height in pixels; smaller sources are not enlarged.
        public var maxHeight: CGFloat = 620
        /// Use a colour key instead of Vision. Faster and cleaner on a true green screen.
        public var greenKey = false
        /// Keep only this part of the clip, in seconds.
        public var from: Double = 0
        public var to: Double?

        public init() {}
    }

    public struct Result {
        public let frames: Int
        public let size: CGSize
        public let bytes: Int
        /// Frames where no character was found; the previous frame was reused.
        public let misses: Int
        public let removedGreenSpill: Bool
    }

    public enum Failure: LocalizedError {
        case noVideo, unreadable(String), noCharacter, writeFailed(String), needsNewerMacOS

        public var errorDescription: String? {
            switch self {
            case .noVideo: return "That file has no video in it."
            case .unreadable(let why): return "Couldn't read the video: \(why)"
            case .noCharacter: return "Couldn't find a character in the video. Try a plainer background."
            case .writeFailed(let why): return "Couldn't write the clip: \(why)"
            case .needsNewerMacOS: return "Cutting out the background needs macOS 14 or later. Use a green-screen clip instead."
            }
        }
    }

    private let input: URL
    private let options: Options
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    private var removesGreenSpill = false
    /// Readers must outlive the outputs read from them.
    private var readers: [AVAssetReader] = []

    public init(input: URL, options: Options = Options()) {
        self.input = input
        self.options = options
    }

    /// Converts the video and writes it to `output`, replacing any file there.
    /// `progress` gets 0…1 as frames are written.
    public func convert(to output: URL, progress: @escaping (Double) -> Void = { _ in }) async throws -> Result {
        if !options.greenKey, #unavailable(macOS 14) { throw Failure.needsNewerMacOS }

        let asset = AVURLAsset(url: input)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw Failure.noVideo }
        let (naturalSize, transform, duration) = try await (track.load(.naturalSize), track.load(.preferredTransform),
                                                             asset.load(.duration))
        let shown = naturalSize.applying(transform)
        let sourceSize = CGSize(width: abs(shown.width), height: abs(shown.height))
        let end = options.to ?? duration.seconds
        let length = max(end - options.from, 0.01)

        func reader() throws -> AVAssetReaderTrackOutput {
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ])
            output.alwaysCopiesSampleData = false
            reader.add(output)
            reader.timeRange = CMTimeRange(start: CMTime(seconds: options.from, preferredTimescale: 600),
                                           end: CMTime(seconds: end, preferredTimescale: 600))
            guard reader.startReading() else { throw Failure.unreadable(reader.error?.localizedDescription ?? "unknown error") }
            readers.append(reader)
            return output
        }

        /// The cut-out frame, upright, with its lower-left corner at the origin.
        func cutOut(_ frame: CVPixelBuffer) -> CIImage? {
            guard let cut = options.greenKey ? keyOutGreen(frame) : cutOutSubject(frame) else { return nil }
            let upright = cut.transformed(by: transform)
            return upright.transformed(by: CGAffineTransform(translationX: -upright.extent.minX, y: -upright.extent.minY))
        }

        // Green screen? Some generators open on the still they started from, on a different
        // background, so look a few frames in.
        do {
            let output = try reader()
            for _ in 0..<12 {
                guard let sample = output.copyNextSampleBuffer() else { break }
                if let frame = CMSampleBufferGetImageBuffer(sample), Self.hasGreenBackground(frame) {
                    removesGreenSpill = true
                    break
                }
            }
        }

        // Pass 1: the box the character moves within. Every third frame is enough.
        var box = CGRect.null
        do {
            let output = try reader()
            var i = 0
            while let sample = output.copyNextSampleBuffer() {
                defer { i += 1 }
                guard i % 3 == 0, let frame = CMSampleBufferGetImageBuffer(sample), let cut = cutOut(frame),
                      let bounds = opaqueBounds(cut, in: sourceSize) else { continue }
                box = box.union(bounds)
                progress(0.3 * min(1, (CMSampleBufferGetPresentationTimeStamp(sample).seconds - options.from) / length))
            }
        }
        guard !box.isNull else { throw Failure.noCharacter }
        // A little room around the character, less below so its feet stay on the floor.
        let pad = box.height * 0.04
        let crop = CGRect(x: box.minX - pad, y: box.minY - pad * 0.25, width: box.width + pad * 2, height: box.height + pad * 1.25)
            .intersection(CGRect(origin: .zero, size: sourceSize))
        let scale = min(1, options.maxHeight / crop.height)
        // HEVC wants even dimensions.
        let outSize = CGSize(width: (crop.width * scale / 2).rounded() * 2, height: (crop.height * scale / 2).rounded() * 2)

        // Pass 2: cut out, crop and encode every frame, into a temporary file first.
        let temp = output.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: temp, fileType: .mov)
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
        let output2 = try reader()
        let start = CMTime(seconds: options.from, preferredTimescale: 600)
        while let sample = output2.copyNextSampleBuffer() {
            guard let frame = CMSampleBufferGetImageBuffer(sample) else { continue }
            let time = CMSampleBufferGetPresentationTimeStamp(sample)
            // Vision occasionally finds nothing in a blurry frame; reuse the last good one so it doesn't blink.
            var cut = cutOut(frame)
            if cut == nil { misses += 1; cut = lastGood }
            lastGood = cut
            guard let cut else { continue }
            let placed = cut
                .cropped(to: crop)
                .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))

            while !writerInput.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
            guard let pool = adaptor.pixelBufferPool else { throw Failure.writeFailed(writer.error?.localizedDescription ?? "no buffer pool") }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { continue }
            context.render(placed, to: buffer, bounds: CGRect(origin: .zero, size: outSize), colorSpace: srgb)
            adaptor.append(buffer, withPresentationTime: time - start)
            frames += 1
            progress(0.3 + 0.7 * min(1, (time.seconds - options.from) / length))
        }

        writerInput.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: temp)
            throw Failure.writeFailed(writer.error?.localizedDescription ?? "unknown error")
        }
        try? FileManager.default.removeItem(at: output)
        try FileManager.default.moveItem(at: temp, to: output)
        progress(1)

        let bytes = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
        return Result(frames: frames, size: outSize, bytes: bytes, misses: misses, removedGreenSpill: removesGreenSpill)
    }

    // MARK: - Background removal

    /// Vision finds the subject and returns a soft mask; everything else becomes transparent.
    private func cutOutSubject(_ frame: CVPixelBuffer) -> CIImage? {
        guard #available(macOS 14, *) else { return nil }
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

    private func keyOutGreen(_ frame: CVPixelBuffer) -> CIImage? {
        let key = Self.makeGreenKey()
        key.setValue(source(frame), forKey: kCIInputImageKey)
        return key.outputImage
    }

    private func source(_ frame: CVPixelBuffer) -> CIImage {
        let image = CIImage(cvPixelBuffer: frame)
        guard removesGreenSpill else { return image }
        let despill = Self.makeDespill()
        despill.setValue(image, forKey: kCIInputImageKey)
        return despill.outputImage ?? image
    }

    /// Where the character's pixels are in a frame, found on a quarter-size copy.
    private func opaqueBounds(_ image: CIImage, in sourceSize: CGSize) -> CGRect? {
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
    static func hasGreenBackground(_ frame: CVPixelBuffer) -> Bool {
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

    // MARK: - Colour cubes

    private static let despillData = cube { r, g, b in [r, min(g, max(r, b)), b, 1] }

    /// Pulls green back to the level of the other channels wherever it dominates: removes the
    /// green tint a green screen bounces onto the character's edges, leaving other colours alone.
    private static func makeDespill() -> CIFilter { filter(despillData) }

    private static let greenKeyData = cube { r, g, b in
        let maxC = max(r, g, b), minC = min(r, g, b)
        let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
        // Green dominates both other channels clearly: background.
        let alpha: Float = (g > 0.25 && g > r * 1.3 && g > b * 1.3 && saturation > 0.3) ? 0 : 1
        // Premultiplied: transparent pixels carry no colour, so no green fringe.
        return [r * alpha, g * alpha, b * alpha, alpha]
    }

    /// Makes green-screen greens transparent and keeps everything else.
    private static func makeGreenKey() -> CIFilter { filter(greenKeyData) }

    private static let cubeSize = 64

    private static func cube(_ map: (Float, Float, Float) -> [Float]) -> Data {
        var values = [Float]()
        values.reserveCapacity(cubeSize * cubeSize * cubeSize * 4)
        let top = Float(cubeSize - 1)
        for b in 0..<cubeSize {
            for g in 0..<cubeSize {
                for r in 0..<cubeSize { values += map(Float(r) / top, Float(g) / top, Float(b) / top) }
            }
        }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private static func filter(_ data: Data) -> CIFilter {
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.cubeDimension = Float(cubeSize)
        filter.cubeData = data
        filter.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        return filter
    }
}
