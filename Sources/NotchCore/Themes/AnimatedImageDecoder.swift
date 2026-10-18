import CoreGraphics
import Foundation
import ImageIO

struct DecodedAnimation: @unchecked Sendable {
    let frames: [CGImage]
    let delays: [Double]

    var duration: Double { delays.reduce(0, +) }

    var keyTimes: [Double] {
        let total = duration
        guard total > 0 else { return [0, 1] }
        var elapsed = 0.0
        let starts = delays.map { delay -> Double in
            defer { elapsed += delay }
            return elapsed / total
        }
        return starts + [1]
    }

    var aspect: Double {
        guard let first = frames.first, first.height > 0 else { return 1 }
        return Double(first.width) / Double(first.height)
    }
}

enum AnimatedImageDecoder {
    static let fallbackDelay = 0.1
    static let minimumDelay = 0.02
    static let maximumFrames = 300

    private static var delayKeys: [(dictionary: CFString, unclamped: CFString, clamped: CFString)] { [
        (kCGImagePropertyGIFDictionary, kCGImagePropertyGIFUnclampedDelayTime, kCGImagePropertyGIFDelayTime),
        (kCGImagePropertyPNGDictionary, kCGImagePropertyAPNGUnclampedDelayTime, kCGImagePropertyAPNGDelayTime),
        (kCGImagePropertyWebPDictionary, kCGImagePropertyWebPUnclampedDelayTime, kCGImagePropertyWebPDelayTime),
        (kCGImagePropertyHEICSDictionary, kCGImagePropertyHEICSUnclampedDelayTime, kCGImagePropertyHEICSDelayTime),
    ] }

    static func decode(url: URL, maxPixelSize: Int) -> DecodedAnimation? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = min(CGImageSourceGetCount(source), maximumFrames)
        guard count > 0 else { return nil }

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary

        let decoded = (0..<count).compactMap { index -> (CGImage, Double)? in
            guard let frame = CGImageSourceCreateThumbnailAtIndex(source, index, options) else { return nil }
            return (frame, delay(of: source, at: index))
        }
        guard !decoded.isEmpty else { return nil }
        return DecodedAnimation(frames: decoded.map(\.0), delays: decoded.map(\.1))
    }

    private static func delay(of source: CGImageSource, at index: Int) -> Double {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
        for keys in delayKeys {
            guard let dictionary = properties[keys.dictionary] as? [CFString: Any] else { continue }
            let raw = (dictionary[keys.unclamped] as? Double) ?? (dictionary[keys.clamped] as? Double) ?? 0
            return raw < minimumDelay ? fallbackDelay : raw
        }
        return fallbackDelay
    }
}
