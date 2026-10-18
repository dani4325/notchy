import AVFoundation
import CoreGraphics
import ImageIO
import os

enum PaletteExtractor {
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "palette")
    private static let sampleSide = 48
    private static let iterations = 10

    static func clusters(from image: CGImage, count: Int) -> [WeightedColor] {
        let pixels = samplePixels(of: image)
        guard !pixels.isEmpty, count > 0 else { return [] }

        var means = seeds(from: pixels, count: count)
        var assignment = [Int](repeating: 0, count: pixels.count)
        for _ in 0..<iterations {
            assignment = pixels.map { nearest(to: $0, in: means) }
            means = means.indices.map { cluster in
                let members = pixels.indices.filter { assignment[$0] == cluster }.map { pixels[$0] }
                return members.isEmpty ? means[cluster] : average(members)
            }
        }

        let total = Double(pixels.count)
        return means.indices.compactMap { cluster in
            let size = assignment.lazy.filter { $0 == cluster }.count
            guard size > 0 else { return nil }
            return WeightedColor(color: means[cluster], weight: Double(size) / total)
        }
        .sorted { $0.weight > $1.weight }
    }

    private static func samplePixels(of image: CGImage) -> [RGB] {
        let side = sampleSide
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return [] }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data else { return [] }

        let bytes = data.bindMemory(to: UInt8.self, capacity: side * side * 4)
        return (0..<(side * side)).compactMap { index in
            let alpha = Double(bytes[index * 4 + 3]) / 255
            guard alpha > 0.5 else { return nil }
            return RGB(
                red: Double(bytes[index * 4]) / 255 / alpha,
                green: Double(bytes[index * 4 + 1]) / 255 / alpha,
                blue: Double(bytes[index * 4 + 2]) / 255 / alpha
            )
        }
    }

    private static func seeds(from pixels: [RGB], count: Int) -> [RGB] {
        var chosen = [average(pixels)]
        while chosen.count < count {
            let farthest = pixels.max { a, b in
                distanceToNearest(a, in: chosen) < distanceToNearest(b, in: chosen)
            }!
            guard distanceToNearest(farthest, in: chosen) > 0 else { break }
            chosen.append(farthest)
        }
        return chosen
    }

    private static func nearest(to color: RGB, in means: [RGB]) -> Int {
        means.indices.min { distance(color, means[$0]) < distance(color, means[$1]) } ?? 0
    }

    private static func distanceToNearest(_ color: RGB, in means: [RGB]) -> Double {
        means.map { distance(color, $0) }.min() ?? 0
    }

    private static func distance(_ a: RGB, _ b: RGB) -> Double {
        let dr = a.red - b.red, dg = a.green - b.green, db = a.blue - b.blue
        return dr * dr + dg * dg + db * db
    }

    private static func average(_ colors: [RGB]) -> RGB {
        let count = Double(colors.count)
        return RGB(
            red: colors.reduce(0) { $0 + $1.red } / count,
            green: colors.reduce(0) { $0 + $1.green } / count,
            blue: colors.reduce(0) { $0 + $1.blue } / count
        )
    }

    static func firstFrame(of url: URL, kind: MediaKind) async -> CGImage? {
        switch kind {
        case .image, .animatedImage:
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        case .video:
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            do {
                return try await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)).image
            } catch {
                logger.error("video frame failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
    }
}
