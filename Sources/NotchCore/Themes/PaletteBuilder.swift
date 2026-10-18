import Foundation

struct WeightedColor: Equatable, Sendable {
    let color: RGB
    let weight: Double
}

enum PaletteBuilder {
    static let minimumAccentBrightness = 0.75
    static let minimumAccentSaturation = 0.45
    static let maximumPanelBrightness = 0.14
    static let minimumHueDistance = 0.08

    static func palette(from clusters: [WeightedColor]) -> ThemePalette {
        let usable = clusters.filter { $0.weight > 0 }
        guard !usable.isEmpty else { return Theme.notchyDefault.palette }

        let ranked = usable.sorted { vividness($0) > vividness($1) }
        let accentSource = ranked[0].color
        let accent = asAccent(accentSource)

        let distinct = ranked.dropFirst().first {
            $0.color.saturation > 0.2 && hueDistance($0.color.hue, accentSource.hue) > minimumHueDistance
        }
        let secondary = distinct.map { asAccent($0.color) }
            ?? RGB(hue: accentSource.hue + 0.08, saturation: max(accent.saturation * 0.7, 0.35), brightness: 1)

        let darkest = usable.min { $0.color.brightness < $1.color.brightness }!.color
        let panel = RGB(
            hue: darkest.hue,
            saturation: min(darkest.saturation, 0.6),
            brightness: min(darkest.brightness, maximumPanelBrightness)
        )
        let text = RGB(hue: accentSource.hue, saturation: 0.04, brightness: 1)

        return ThemePalette(
            accent: HexColor(rgb: accent),
            secondary: HexColor(rgb: secondary),
            panel: HexColor(rgb: panel),
            text: HexColor(rgb: text),
            source: .automatic
        )
    }

    static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let raw = abs(a - b)
        return min(raw, 1 - raw)
    }

    private static func vividness(_ cluster: WeightedColor) -> Double {
        cluster.color.saturation * cluster.color.brightness * cluster.weight.squareRoot()
    }

    private static func asAccent(_ color: RGB) -> RGB {
        RGB(
            hue: color.hue,
            saturation: max(color.saturation, color.saturation < 0.08 ? 0 : minimumAccentSaturation),
            brightness: max(color.brightness, minimumAccentBrightness)
        )
    }
}
