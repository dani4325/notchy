import Foundation

public struct RGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(hue: Double, saturation: Double, brightness: Double) {
        let h = (hue - floor(hue)) * 6
        let c = brightness * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        let (r, g, b): (Double, Double, Double) = switch Int(h) {
        case 0: (c, x, 0)
        case 1: (x, c, 0)
        case 2: (0, c, x)
        case 3: (0, x, c)
        case 4: (x, 0, c)
        default: (c, 0, x)
        }
        self.init(red: r + m, green: g + m, blue: b + m)
    }

    public var brightness: Double { max(red, green, blue) }

    public var saturation: Double {
        let maximum = brightness
        return maximum == 0 ? 0 : (maximum - min(red, green, blue)) / maximum
    }

    public var hue: Double {
        let maximum = brightness
        let delta = maximum - min(red, green, blue)
        guard delta > 0 else { return 0 }
        let raw: Double = switch maximum {
        case red: ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        case green: (blue - red) / delta + 2
        default: (red - green) / delta + 4
        }
        let hue = raw / 6
        return hue < 0 ? hue + 1 : hue
    }
}

public struct HexColor: Codable, Hashable, Sendable {
    public let hex: String

    public init?(_ string: String) {
        var digits = string.trimmingCharacters(in: .whitespaces).uppercased()
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6 || digits.count == 8,
              digits.allSatisfy(\.isHexDigit)
        else { return nil }
        hex = "#" + digits
    }

    public init(rgb: RGB, alpha: Double = 1) {
        let components = [rgb.red, rgb.green, rgb.blue] + (alpha < 1 ? [alpha] : [])
        hex = "#" + components.map { String(format: "%02X", Int((min(max($0, 0), 1) * 255).rounded())) }.joined()
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let color = HexColor(raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Color no válido: \(raw)"))
        }
        self = color
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }

    private func component(_ index: Int) -> Double {
        let start = hex.index(hex.startIndex, offsetBy: 1 + index * 2)
        return Double(UInt8(hex[start..<hex.index(start, offsetBy: 2)], radix: 16) ?? 0) / 255
    }

    public var red: Double { component(0) }
    public var green: Double { component(1) }
    public var blue: Double { component(2) }
    public var alpha: Double { hex.count == 9 ? component(3) : 1 }

    public var rgb: RGB { RGB(red: red, green: green, blue: blue) }
}
