import CoreGraphics
import Foundation

struct BackgroundSample: Equatable, Sendable, Codable {
    static let columnsAcross = 128
    static let maximumRows = 256
    static let maximumMeasuredWidth = 2048

    let columns: Int
    let rows: Int
    let mediaAspect: Double
    private(set) var upper: [RGB]
    private(set) var lower: [RGB]

    private enum CodingKeys: String, CodingKey {
        case columns, rows, mediaAspect, upper, lower
    }

    private init(columns: Int, rows: Int, mediaAspect: Double) {
        self.columns = columns
        self.rows = rows
        self.mediaAspect = mediaAspect
        upper = Array(repeating: RGB(red: 0, green: 0, blue: 0), count: columns * rows)
        lower = Array(repeating: RGB(red: 1, green: 1, blue: 1), count: columns * rows)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        columns = try container.decode(Int.self, forKey: .columns)
        rows = try container.decode(Int.self, forKey: .rows)
        mediaAspect = try container.decode(Double.self, forKey: .mediaAspect)
        let count = columns * rows
        guard columns > 0, rows > 0, mediaAspect > 0 else {
            throw DecodingError.dataCorruptedError(forKey: .columns, in: container, debugDescription: "empty measurement")
        }
        upper = try Self.colors(container.decode(Data.self, forKey: .upper), count: count, key: .upper, in: container)
        lower = try Self.colors(container.decode(Data.self, forKey: .lower), count: count, key: .lower, in: container)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(columns, forKey: .columns)
        try container.encode(rows, forKey: .rows)
        try container.encode(mediaAspect, forKey: .mediaAspect)
        try container.encode(Self.bytes(upper), forKey: .upper)
        try container.encode(Self.bytes(lower), forKey: .lower)
    }

    static func measuring(_ image: CGImage, backdrop: RGB = RGB(red: 0, green: 0, blue: 0)) -> BackgroundSample? {
        guard image.width > 0, image.height > 0 else { return nil }
        let aspect = Double(image.width) / Double(image.height)
        let width = min(image.width, maximumMeasuredWidth)
        let height = max(Int((Double(width) / aspect).rounded()), 1)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.setFillColor(red: backdrop.red, green: backdrop.green, blue: backdrop.blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }

        let columns = min(columnsAcross, width)
        let rows = min(max(Int((Double(columns) / aspect).rounded()), 1), min(maximumRows, height))
        var sample = BackgroundSample(columns: columns, rows: rows, mediaAspect: aspect)
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        for y in 0..<height {
            let row = y * rows / height
            for x in 0..<width {
                let index = (y * width + x) * 4
                let color = RGB(red: Double(pixels[index]) / 255, green: Double(pixels[index + 1]) / 255, blue: Double(pixels[index + 2]) / 255)
                sample.include(color, cell: row * columns + x * columns / width)
            }
        }
        return sample
    }

    func merged(with other: BackgroundSample) -> BackgroundSample {
        guard other.columns == columns, other.rows == rows else { return self }
        var result = self
        for cell in upper.indices {
            result.include(other.upper[cell], cell: cell)
            result.include(other.lower[cell], cell: cell)
        }
        return result
    }

    func framed(crop: MediaCrop, targetAspect: Double) -> FramedSample {
        FramedSample(sample: self, window: crop.rect(mediaAspect: mediaAspect, targetAspect: targetAspect))
    }

    fileprivate func cells(columns columnRange: Range<Int>, rows rowRange: Range<Int>) -> [(upper: RGB, lower: RGB)] {
        rowRange.flatMap { row in
            columnRange.map { column in (upper[row * columns + column], lower[row * columns + column]) }
        }
    }

    private mutating func include(_ color: RGB, cell: Int) {
        let high = upper[cell], low = lower[cell]
        upper[cell] = RGB(red: max(high.red, color.red), green: max(high.green, color.green), blue: max(high.blue, color.blue))
        lower[cell] = RGB(red: min(low.red, color.red), green: min(low.green, color.green), blue: min(low.blue, color.blue))
    }

    private static func bytes(_ colors: [RGB]) -> Data {
        Data(colors.flatMap { [$0.red, $0.green, $0.blue].map { UInt8((min(max($0, 0), 1) * 255).rounded()) } })
    }

    private static func colors(_ data: Data, count: Int, key: CodingKeys, in container: KeyedDecodingContainer<CodingKeys>) throws -> [RGB] {
        guard data.count == count * 3 else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "measurement size mismatch")
        }
        let values = [UInt8](data)
        return (0..<count).map { RGB(red: Double(values[$0 * 3]) / 255, green: Double(values[$0 * 3 + 1]) / 255, blue: Double(values[$0 * 3 + 2]) / 255) }
    }
}

struct FramedSample: Sendable {
    let sample: BackgroundSample
    let window: CGRect

    func cells(in zone: ScrimZone) -> [(upper: RGB, lower: RGB)] {
        let horizontal = (window.minX + zone.horizontal.lowerBound * window.width)...(window.minX + zone.horizontal.upperBound * window.width)
        let vertical = (window.minY + zone.vertical.lowerBound * window.height)...(window.minY + zone.vertical.upperBound * window.height)
        return sample.cells(columns: Self.indices(horizontal, count: sample.columns), rows: Self.indices(vertical, count: sample.rows))
    }

    private static func indices(_ range: ClosedRange<Double>, count: Int) -> Range<Int> {
        let start = min(max(Int((range.lowerBound * Double(count)).rounded(.down)), 0), count - 1)
        let end = min(max(Int((range.upperBound * Double(count)).rounded(.up)), start + 1), count)
        return start..<end
    }
}

struct BackgroundMeasurement: Equatable, Sendable, Codable {
    let sample: BackgroundSample
    let framesChecked: Int
    let coversEveryFrame: Bool
}

struct ScrimZone: Sendable {
    struct Foreground: Sendable {
        let color: RGB
        let opacity: Double
        let use: ContrastCorrection.Use
    }

    let horizontal: ClosedRange<Double>
    let vertical: ClosedRange<Double>
    let foregrounds: [Foreground]
}

enum LegibilityPlanner {
    private static let precision = 0.005

    static func strength(for zone: ScrimZone, over sample: FramedSample, scrim: RGB, atLeast minimum: Double) -> Double {
        let floor = min(max(minimum, 0), 1)
        let passes = { (strength: Double) in
            zone.foregrounds.allSatisfy { ratio(of: $0, in: zone, over: sample, scrim: scrim, strength: strength) >= $0.use.minimumRatio }
        }
        if passes(floor) { return floor }
        if !passes(1) { return 1 }
        var low = floor, high = 1.0
        while high - low > precision {
            let middle = (low + high) / 2
            if passes(middle) { high = middle } else { low = middle }
        }
        return high
    }

    static func worstRatio(for zone: ScrimZone, over sample: FramedSample, scrim: RGB, strength: Double) -> Double {
        zone.foregrounds.map { ratio(of: $0, in: zone, over: sample, scrim: scrim, strength: strength) }.min() ?? 21
    }

    private enum Blending: CaseIterable {
        case encoded
        case linear
    }

    private static func ratio(of foreground: ScrimZone.Foreground, in zone: ScrimZone, over sample: FramedSample, scrim: RGB, strength: Double) -> Double {
        sample.cells(in: zone).flatMap { cell in
            Blending.allCases.map { blending in
                let bright = blend(scrim, over: cell.upper, amount: strength, blending)
                let dark = blend(scrim, over: cell.lower, amount: strength, blending)
                let lighterThanBright = foreground.color.relativeLuminance >= bright.relativeLuminance
                let lighterThanDark = foreground.color.relativeLuminance >= dark.relativeLuminance
                guard lighterThanBright == lighterThanDark else { return 1.0 }
                let onBright = blend(foreground.color, over: bright, amount: foreground.opacity, blending)
                let onDark = blend(foreground.color, over: dark, amount: foreground.opacity, blending)
                return min(onBright.contrastRatio(with: bright), onDark.contrastRatio(with: dark))
            }
        }.min() ?? 21
    }

    private static func blend(_ top: RGB, over bottom: RGB, amount: Double, _ blending: Blending) -> RGB {
        let mix: (Double, Double) -> Double = switch blending {
        case .encoded: { amount * $0 + (1 - amount) * $1 }
        case .linear: { OKLCH.encode(amount * OKLCH.linear($0) + (1 - amount) * OKLCH.linear($1)) }
        }
        return RGB(red: mix(top.red, bottom.red), green: mix(top.green, bottom.green), blue: mix(top.blue, bottom.blue))
    }
}
