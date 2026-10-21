import CoreGraphics
import Foundation

struct VeilSpot: Equatable, Sendable {
    let rect: CGRect
    let strength: Double
}

struct VeilMask {
    static let pixelsPerPoint: CGFloat = 0.5
    static let reaches: [Double] = Array(stride(from: 1.0, through: 3.5, by: 0.25))

    static func coverage(reach: Double) -> Double {
        pow(erf(reach / 2.0.squareRoot()), 2)
    }

    let width: Int
    let height: Int
    private let pointsPerPixel: CGFloat
    private let values: [Double]

    init(size: CGSize, spots: [VeilSpot], feather: CGFloat) {
        let scale = Self.pixelsPerPoint
        width = max(Int((size.width * scale).rounded(.up)), 1)
        height = max(Int((size.height * scale).rounded(.up)), 1)
        pointsPerPixel = 1 / scale
        var field = [Double](repeating: 0, count: width * height)
        for spot in spots where spot.strength > 0 {
            let reach = Self.reaches.first { spot.strength / Self.coverage(reach: $0) <= 1 } ?? Self.reaches.last!
            let target = min(spot.strength / Self.coverage(reach: reach), 1)
            let area = spot.rect.insetBy(dx: -CGFloat(reach) * feather, dy: -CGFloat(reach) * feather)
            let minX = max(Int((area.minX * scale).rounded(.down)), 0), maxX = min(Int((area.maxX * scale).rounded(.up)), width - 1)
            let minY = max(Int((area.minY * scale).rounded(.down)), 0), maxY = min(Int((area.maxY * scale).rounded(.up)), height - 1)
            guard minX <= maxX, minY <= maxY else { continue }
            for y in minY...maxY {
                for x in minX...maxX {
                    field[y * width + x] = max(field[y * width + x], target)
                }
            }
        }
        values = Self.blurred(field, width: width, height: height, sigma: Double(feather * scale))
    }

    func value(at point: CGPoint) -> Double {
        let x = (point.x / pointsPerPixel).clamped(to: 0...CGFloat(width - 1))
        let y = (point.y / pointsPerPixel).clamped(to: 0...CGFloat(height - 1))
        let x0 = Int(x.rounded(.down)), y0 = Int(y.rounded(.down))
        let x1 = min(x0 + 1, width - 1), y1 = min(y0 + 1, height - 1)
        let fx = Double(x) - Double(x0), fy = Double(y) - Double(y0)
        let top = values[y0 * width + x0] * (1 - fx) + values[y0 * width + x1] * fx
        let bottom = values[y1 * width + x0] * (1 - fx) + values[y1 * width + x1] * fx
        return top * (1 - fy) + bottom * fy
    }

    func image(color: RGB) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for index in values.indices {
            let alpha = values[index].clamped(to: 0...1)
            bytes[index * 4] = UInt8((color.red * alpha * 255).rounded())
            bytes[index * 4 + 1] = UInt8((color.green * alpha * 255).rounded())
            bytes[index * 4 + 2] = UInt8((color.blue * alpha * 255).rounded())
            bytes[index * 4 + 3] = UInt8((alpha * 255).rounded(.up))
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(bytes) as CFData)
        else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }

    private static func blurred(_ field: [Double], width: Int, height: Int, sigma: Double) -> [Double] {
        guard sigma > 0 else { return field }
        let radius = Int((sigma * 3).rounded(.up))
        let raw = (-radius...radius).map { exp(-Double($0 * $0) / (2 * sigma * sigma)) }
        let total = raw.reduce(0, +)
        let kernel = raw.map { $0 / total }
        var horizontal = [Double](repeating: 0, count: field.count)
        for y in 0..<height {
            for x in 0..<width {
                var sum = 0.0
                for (offset, weight) in kernel.enumerated() {
                    let sx = min(max(x + offset - radius, 0), width - 1)
                    sum += field[y * width + sx] * weight
                }
                horizontal[y * width + x] = sum
            }
        }
        var result = [Double](repeating: 0, count: field.count)
        for y in 0..<height {
            for x in 0..<width {
                var sum = 0.0
                for (offset, weight) in kernel.enumerated() {
                    let sy = min(max(y + offset - radius, 0), height - 1)
                    sum += horizontal[sy * width + x] * weight
                }
                result[y * width + x] = sum
            }
        }
        return result
    }
}
