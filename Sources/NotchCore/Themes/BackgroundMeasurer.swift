import AVFoundation
import ImageIO

enum BackgroundMeasurer {
    static let videoSampleInterval = 0.5
    static let maximumVideoSamples = 240
    static let animationPixelSize = 1024

    static func measureInBackground(_ url: URL, kind: MediaKind) async -> BackgroundMeasurement? {
        await Task.detached(priority: .utility) { await measure(url, kind: kind) }.value
    }

    static func measure(_ url: URL, kind: MediaKind) async -> BackgroundMeasurement? {
        switch kind {
        case .image:
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  let sample = BackgroundSample.measuring(image)
            else { return nil }
            return BackgroundMeasurement(sample: sample, framesChecked: 1, coversEveryFrame: true)
        case .animatedImage:
            guard let animation = AnimatedImageDecoder.decode(url: url, maxPixelSize: animationPixelSize) else { return nil }
            var combined: BackgroundSample?
            for frame in animation.frames {
                guard let sample = BackgroundSample.measuring(frame) else { return nil }
                combined = combined.map { $0.merged(with: sample) } ?? sample
            }
            return combined.map { BackgroundMeasurement(sample: $0, framesChecked: animation.frames.count, coversEveryFrame: true) }
        case .video:
            return await measureVideo(url)
        }
    }

    private static func measureVideo(_ url: URL) async -> BackgroundMeasurement? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration).seconds, duration.isFinite, duration > 0 else { return nil }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: BackgroundSample.maximumMeasuredWidth, height: BackgroundSample.maximumMeasuredWidth)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let count = min(Int(duration / videoSampleInterval) + 1, maximumVideoSamples)
        var combined: BackgroundSample?
        var checked = 0
        for index in 0..<count {
            let time = CMTime(seconds: duration * Double(index) / Double(count), preferredTimescale: 600)
            guard let frame = try? await generator.image(at: time).image,
                  let sample = BackgroundSample.measuring(frame)
            else { continue }
            combined = combined.map { $0.merged(with: sample) } ?? sample
            checked += 1
        }
        return combined.map { BackgroundMeasurement(sample: $0, framesChecked: checked, coversEveryFrame: false) }
    }
}
