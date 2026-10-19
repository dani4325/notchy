import Foundation

struct OKLCH: Equatable, Sendable {
    let lightness: Double
    let chroma: Double
    let hue: Double

    private static let gamutTolerance = 1e-6
    private static let chromaPrecision = 1e-5

    init(lightness: Double, chroma: Double, hue: Double) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
    }

    init(_ rgb: RGB) {
        let r = Self.linear(rgb.red), g = Self.linear(rgb.green), b = Self.linear(rgb.blue)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        let a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let bAxis = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        self.init(
            lightness: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            chroma: hypot(a, bAxis),
            hue: atan2(bAxis, a)
        )
    }

    var hueDegrees: Double {
        let degrees = hue * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    var linearSRGB: (red: Double, green: Double, blue: Double) {
        let a = chroma * cos(hue), b = chroma * sin(hue)
        let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
        return (
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        )
    }

    var isInSRGB: Bool {
        let channels = linearSRGB
        return [channels.red, channels.green, channels.blue].allSatisfy {
            $0 >= -Self.gamutTolerance && $0 <= 1 + Self.gamutTolerance
        }
    }

    func mappedIntoSRGB() -> OKLCH {
        if lightness >= 1 { return OKLCH(lightness: 1, chroma: 0, hue: hue) }
        if lightness <= 0 { return OKLCH(lightness: 0, chroma: 0, hue: hue) }
        if isInSRGB { return self }
        var low = 0.0, high = chroma
        while high - low > Self.chromaPrecision {
            let middle = (low + high) / 2
            if OKLCH(lightness: lightness, chroma: middle, hue: hue).isInSRGB {
                low = middle
            } else {
                high = middle
            }
        }
        return OKLCH(lightness: lightness, chroma: low, hue: hue)
    }

    var rgb: RGB {
        let channels = linearSRGB
        return RGB(red: Self.encode(channels.red), green: Self.encode(channels.green), blue: Self.encode(channels.blue))
    }

    static func linear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    static func encode(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }
}
