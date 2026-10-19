import CoreGraphics
import Foundation

struct BackgroundSample: Sendable {
    static let maximumColumns = 96
    static let maximumRows = 24

    let columns: Int
    let rows: Int
    private(set) var upper: [RGB]
    private(set) var lower: [RGB]

    private init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        upper = Array(repeating: RGB(red: 0, green: 0, blue: 0), count: columns * rows)
        lower = Array(repeating: RGB(red: 1, green: 1, blue: 1), count: columns * rows)
    }

    static func measuring(_ image: CGImage, crop: MediaCrop, size: CGSize, backdrop: RGB = RGB(red: 0, green: 0, blue: 0)) -> BackgroundSample? {
        let width = Int(size.width.rounded()), height = Int(size.height.rounded())
        guard width > 0, height > 0, image.width > 0, image.height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.setFillColor(red: backdrop.red, green: backdrop.green, blue: backdrop.blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let window = crop.rect(mediaAspect: Double(image.width) / Double(image.height), targetAspect: Double(width) / Double(height))
        let content = CGSize(width: Double(width) / window.width, height: Double(height) / window.height)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(
            x: -window.minX * content.width,
            y: Double(height) + window.minY * content.height - content.height,
            width: content.width,
            height: content.height
        ))
        guard let data = context.data else { return nil }

        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var sample = BackgroundSample(columns: min(width, maximumColumns), rows: min(height, maximumRows))
        for y in 0..<height {
            let row = y * sample.rows / height
            for x in 0..<width {
                let index = (y * width + x) * 4
                let color = RGB(red: Double(pixels[index]) / 255, green: Double(pixels[index + 1]) / 255, blue: Double(pixels[index + 2]) / 255)
                sample.include(color, cell: row * sample.columns + x * sample.columns / width)
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

    func cells(in zone: ScrimZone) -> [(upper: RGB, lower: RGB)] {
        let columnRange = Self.indices(zone.horizontal, count: columns)
        let rowRange = Self.indices(zone.vertical, count: rows)
        return rowRange.flatMap { row in
            columnRange.map { column in (upper[row * columns + column], lower[row * columns + column]) }
        }
    }

    private mutating func include(_ color: RGB, cell: Int) {
        let high = upper[cell], low = lower[cell]
        upper[cell] = RGB(red: max(high.red, color.red), green: max(high.green, color.green), blue: max(high.blue, color.blue))
        lower[cell] = RGB(red: min(low.red, color.red), green: min(low.green, color.green), blue: min(low.blue, color.blue))
    }

    private static func indices(_ range: ClosedRange<Double>, count: Int) -> Range<Int> {
        let start = min(max(Int((range.lowerBound * Double(count)).rounded(.down)), 0), count - 1)
        let end = min(max(Int((range.upperBound * Double(count)).rounded(.up)), start + 1), count)
        return start..<end
    }
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
    struct Stop: Equatable, Sendable {
        let location: Double
        let value: Double
    }

    private static let precision = 0.005

    static func strength(for zone: ScrimZone, over sample: BackgroundSample, scrim: RGB, atLeast minimum: Double) -> Double {
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

    static func worstRatio(for zone: ScrimZone, over sample: BackgroundSample, scrim: RGB, strength: Double) -> Double {
        zone.foregrounds.map { ratio(of: $0, in: zone, over: sample, scrim: scrim, strength: strength) }.min() ?? 21
    }

    static func stops(boundaries: [Double], strengths: [Double], ramp: Double) -> [Stop] {
        guard let first = strengths.first, let last = strengths.last, strengths.count == boundaries.count + 1 else { return [] }
        var stops = [Stop(location: 0, value: first)]
        for (index, boundary) in boundaries.enumerated() {
            let before = strengths[index], after = strengths[index + 1]
            let previous = index == 0 ? 0 : boundaries[index - 1]
            let next = index + 1 < boundaries.count ? boundaries[index + 1] : 1
            if before < after {
                stops.append(Stop(location: max(boundary - ramp, previous), value: before))
                stops.append(Stop(location: boundary, value: after))
            } else {
                stops.append(Stop(location: boundary, value: before))
                stops.append(Stop(location: min(boundary + ramp, next), value: after))
            }
        }
        stops.append(Stop(location: 1, value: last))
        return stops
    }

    static func value(of stops: [Stop], at location: Double) -> Double {
        guard let upperIndex = stops.firstIndex(where: { $0.location >= location }) else { return stops.last?.value ?? 0 }
        guard upperIndex > 0 else { return stops[upperIndex].value }
        let lower = stops[upperIndex - 1], upper = stops[upperIndex]
        let span = upper.location - lower.location
        guard span > 0 else { return max(lower.value, upper.value) }
        return lower.value + (upper.value - lower.value) * (location - lower.location) / span
    }

    private enum Blending: CaseIterable {
        case encoded
        case linear
    }

    private static func ratio(of foreground: ScrimZone.Foreground, in zone: ScrimZone, over sample: BackgroundSample, scrim: RGB, strength: Double) -> Double {
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
