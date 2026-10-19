import AVFoundation
import ImageIO
import Observation
import os

struct BackgroundMeasurement: Sendable {
    let sample: BackgroundSample
    let framesChecked: Int
    let coversEveryFrame: Bool
}

@MainActor
@Observable
final class BackgroundMeasurements {
    struct Key: Hashable, Sendable {
        let url: URL
        let kind: MediaKind
        let crop: MediaCrop
        let width: Int
        let height: Int
        let backdrop: HexColor
    }

    static let shared = BackgroundMeasurements()

    nonisolated static let pixelScale = 2.0
    nonisolated static let videoSampleInterval = 0.5
    nonisolated static let maximumVideoSamples = 240
    nonisolated static let animationPixelSize = 1024
    private static let retainedResults = 8
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "legibility")

    private(set) var results: [Key: BackgroundMeasurement] = [:]
    @ObservationIgnored private var order: [Key] = []

    static func key(for source: MediaSource, crop: MediaCrop, size: CGSize, backdrop: HexColor) -> Key {
        Key(
            url: source.url, kind: source.kind, crop: crop,
            width: Int((size.width * pixelScale).rounded()), height: Int((size.height * pixelScale).rounded()),
            backdrop: backdrop
        )
    }

    func measure(_ key: Key) async {
        guard results[key] == nil, key.width > 0, key.height > 0 else { return }
        let measurement = await Task.detached(priority: .utility) { await Self.measurement(for: key) }.value
        guard !Task.isCancelled else { return }
        guard let measurement else {
            Self.logger.error("could not measure background at \(key.url.lastPathComponent, privacy: .public)")
            return
        }
        results[key] = measurement
        order.append(key)
        if order.count > Self.retainedResults {
            results[order.removeFirst()] = nil
        }
    }

    nonisolated private static func measurement(for key: Key) async -> BackgroundMeasurement? {
        let size = CGSize(width: key.width, height: key.height)
        let backdrop = key.backdrop.rgb
        switch key.kind {
        case .image:
            guard let source = CGImageSourceCreateWithURL(key.url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  let sample = BackgroundSample.measuring(image, crop: key.crop, size: size, backdrop: backdrop)
            else { return nil }
            return BackgroundMeasurement(sample: sample, framesChecked: 1, coversEveryFrame: true)
        case .animatedImage:
            guard let animation = AnimatedImageDecoder.decode(url: key.url, maxPixelSize: animationPixelSize) else { return nil }
            return combine(animation.frames, crop: key.crop, size: size, backdrop: backdrop, coversEveryFrame: true)
        case .video:
            return await videoMeasurement(for: key, size: size, backdrop: backdrop)
        }
    }

    nonisolated private static func videoMeasurement(for key: Key, size: CGSize, backdrop: RGB) async -> BackgroundMeasurement? {
        let asset = AVURLAsset(url: key.url)
        guard let duration = try? await asset.load(.duration).seconds, duration.isFinite, duration > 0 else { return nil }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let count = min(Int(duration / videoSampleInterval) + 1, maximumVideoSamples)
        var combined: BackgroundSample?
        var checked = 0
        for index in 0..<count {
            if Task.isCancelled { return nil }
            let time = CMTime(seconds: duration * Double(index) / Double(count), preferredTimescale: 600)
            guard let frame = try? await generator.image(at: time).image,
                  let sample = BackgroundSample.measuring(frame, crop: key.crop, size: size, backdrop: backdrop)
            else { continue }
            combined = combined.map { $0.merged(with: sample) } ?? sample
            checked += 1
        }
        return combined.map { BackgroundMeasurement(sample: $0, framesChecked: checked, coversEveryFrame: false) }
    }

    nonisolated private static func combine(_ frames: [CGImage], crop: MediaCrop, size: CGSize, backdrop: RGB, coversEveryFrame: Bool) -> BackgroundMeasurement? {
        let samples = frames.compactMap { BackgroundSample.measuring($0, crop: crop, size: size, backdrop: backdrop) }
        guard let first = samples.first, samples.count == frames.count else { return nil }
        let combined = samples.dropFirst().reduce(first) { $0.merged(with: $1) }
        return BackgroundMeasurement(sample: combined, framesChecked: samples.count, coversEveryFrame: coversEveryFrame)
    }
}
