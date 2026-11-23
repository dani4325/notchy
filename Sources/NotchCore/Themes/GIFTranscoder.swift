import AVFoundation
import ImageIO

enum GIFTranscoder {
    enum TranscodeError: Error {
        case unreadable
        case encodingFailed
    }

    static let maximumSide = 1920
    static let minimumDelay = 0.02
    static let fallbackDelay = 0.1

    static let durationTolerance = 0.05

    static func matches(video: URL, gif: URL) async -> Bool {
        guard let source = CGImageSourceCreateWithURL(gif as CFURL, nil), CGImageSourceGetCount(source) > 0,
              let first = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return false }
        let count = CGImageSourceGetCount(source)
        let expectedSize = evenSize(width: first.width, height: first.height)
        let expectedDuration = (0..<count).reduce(0) { $0 + delay(of: source, at: $1) }

        let asset = AVURLAsset(url: video)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize),
              let duration = try? await asset.load(.duration).seconds
        else { return false }
        guard Int(size.width) == expectedSize.width, Int(size.height) == expectedSize.height,
              abs(duration - expectedDuration) <= durationTolerance
        else { return false }
        return await Task.detached { frameCount(of: asset, track: track) == count }.value
    }

    private static func frameCount(of asset: AVURLAsset, track: AVAssetTrack) -> Int? {
        guard let reader = try? AVAssetReader(asset: asset) else { return nil }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else { return nil }
        var frames = 0
        while let sample = output.copyNextSampleBuffer() {
            if CMSampleBufferGetNumSamples(sample) > 0 { frames += 1 }
        }
        return reader.status == .completed ? frames : nil
    }

    private static let encodingQueue = DispatchQueue(label: "com.danirubio.notchy.gif-transcoder", qos: .userInitiated)

    static func transcode(_ gif: URL) async throws -> URL {
        let prepared = try await Task.detached(priority: .userInitiated) {
            try prepare(gif)
        }.value

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("notchy-\(UUID().uuidString)")
            .appendingPathExtension(prepared.transparent ? "mov" : "mp4")

        let writer = try AVAssetWriter(outputURL: output, fileType: prepared.transparent ? .mov : .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: prepared.transparent ? AVVideoCodecType.hevcWithAlpha : AVVideoCodecType.h264,
            AVVideoWidthKey: prepared.size.width,
            AVVideoHeightKey: prepared.size.height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_IEC_sRGB,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: prepared.size.width,
            kCVPixelBufferHeightKey as String: prepared.size.height,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw TranscodeError.encodingFailed }
        writer.startSession(atSourceTime: .zero)

        let totalDuration = try await writeFrames(prepared, to: input, adaptor: adaptor)
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: totalDuration, preferredTimescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw TranscodeError.encodingFailed }
        return output
    }

    private struct PreparedGIF: @unchecked Sendable {
        let frames: [CGImage]
        let delays: [Double]
        let size: (width: Int, height: Int)
        let transparent: Bool
    }

    private static func prepare(_ gif: URL) throws -> PreparedGIF {
        guard let source = CGImageSourceCreateWithURL(gif as CFURL, nil), CGImageSourceGetCount(source) > 0,
              let first = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw TranscodeError.unreadable }
        let count = CGImageSourceGetCount(source)
        let size = evenSize(width: first.width, height: first.height)
        let frames = (0..<count).compactMap { CGImageSourceCreateImageAtIndex(source, $0, nil) }
        guard frames.count == count else { throw TranscodeError.unreadable }
        let delays = (0..<count).map { delay(of: source, at: $0) }
        let transparent = frames.contains(where: hasTransparency)
        return PreparedGIF(frames: frames, delays: delays, size: size, transparent: transparent)
    }

    private static func writeFrames(
        _ prepared: PreparedGIF,
        to input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor
    ) async throws -> Double {
        let feed = FrameFeed(input: input, adaptor: adaptor, prepared: prepared)
        return try await withCheckedThrowingContinuation { continuation in
            feed.input.requestMediaDataWhenReady(on: encodingQueue) {
                while !feed.finished, feed.input.isReadyForMoreMediaData {
                    if feed.index >= feed.prepared.frames.count {
                        feed.finished = true
                        continuation.resume(returning: feed.time)
                        return
                    }
                    guard let pool = feed.adaptor.pixelBufferPool,
                          let buffer = draw(feed.prepared.frames[feed.index], size: feed.prepared.size, pool: pool),
                          feed.adaptor.append(buffer, withPresentationTime: CMTime(seconds: feed.time, preferredTimescale: 600))
                    else {
                        feed.finished = true
                        continuation.resume(throwing: TranscodeError.encodingFailed)
                        return
                    }
                    feed.time += feed.prepared.delays[feed.index]
                    feed.index += 1
                }
            }
        }
    }

    private final class FrameFeed: @unchecked Sendable {
        let input: AVAssetWriterInput
        let adaptor: AVAssetWriterInputPixelBufferAdaptor
        let prepared: PreparedGIF
        var index = 0
        var time = 0.0
        var finished = false

        init(input: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor, prepared: PreparedGIF) {
            self.input = input
            self.adaptor = adaptor
            self.prepared = prepared
        }
    }

    private static func evenSize(width: Int, height: Int) -> (width: Int, height: Int) {
        let scale = min(1, Double(maximumSide) / Double(max(width, height)))
        let even = { (value: Int) in max(Int((Double(value) * scale).rounded()) / 2 * 2, 2) }
        return (even(width), even(height))
    }

    private static func draw(_ frame: CGImage, size: (width: Int, height: Int), pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: CVPixelBufferGetBaseAddress(buffer), width: size.width, height: size.height, bitsPerComponent: 8,
                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              )
        else { return nil }
        CVBufferSetAttachment(buffer, kCVImageBufferCGColorSpaceKey, space, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_sRGB, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
        context.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        context.interpolationQuality = .high
        context.draw(frame, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return buffer
    }

    private static func hasTransparency(_ frame: CGImage) -> Bool {
        switch frame.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        let width = frame.width, height = frame.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return true }
        context.draw(frame, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] < 255 }
    }

    private static func delay(of source: CGImageSource, at index: Int) -> Double {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let value = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? fallbackDelay
        return value < minimumDelay ? fallbackDelay : value
    }
}
