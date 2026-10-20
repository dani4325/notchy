import AppKit
import SwiftUI

public struct ThemeAppearance: Sendable {
    public let theme: Theme
    public let background: MediaSource?
    let measurement: BackgroundMeasurement?

    public init(theme: Theme, background: MediaSource?) {
        self.init(theme: theme, background: background, measurement: nil)
    }

    init(theme: Theme, background: MediaSource?, measurement: BackgroundMeasurement?) {
        self.theme = theme
        self.background = background
        self.measurement = measurement
    }

    var accent: Color { Color(theme.palette.accent) }
    var secondary: Color { Color(theme.palette.secondary) }
    var panel: Color { Color(theme.palette.panel) }
    var text: Color { Color(theme.palette.text) }

    var hasLightText: Bool { theme.palette.text.rgb.brightness > 0.5 }

    static let secondaryTextOpacity = 0.78
    var secondaryTextColor: Color { text.opacity(Self.secondaryTextOpacity) }

    var accentText: Color { color(theme.palette.accent, for: .text) }
    var accentGraphic: Color { color(theme.palette.accent, for: .graphic) }
    var secondaryText: Color { color(theme.palette.secondary, for: .text) }
    var secondaryGraphic: Color { color(theme.palette.secondary, for: .graphic) }

    var colorsReachMinimumOnPanel: Bool {
        let palette = theme.palette
        let checks: [(HexColor, Double, ContrastCorrection.Use)] = ScrimPlan.textOpacities.map { (palette.text, $0, .text) } + [
            (palette.text, 1, .graphic), (palette.accent, 1, .text), (palette.accent, 1, .graphic),
            (palette.secondary, 1, .text), (palette.secondary, 1, .graphic),
        ]
        return checks.allSatisfy { color, opacity, use in
            effective(color, opacity: opacity, for: use).contrastRatio(with: palette.panel.rgb) >= use.minimumRatio
        }
    }

    func color(_ base: HexColor, opacity: Double = 1, for use: ContrastCorrection.Use) -> Color {
        let value = effective(base, opacity: opacity, for: use)
        return Color(.sRGB, red: value.red, green: value.green, blue: value.blue)
    }

    func nsColor(_ base: HexColor, opacity: Double = 1, for use: ContrastCorrection.Use) -> NSColor {
        let value = effective(base, opacity: opacity, for: use)
        return NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: 1)
    }

    var accentBarColor: NSColor { nsColor(theme.palette.accent, for: .graphic) }

    var barTrackColor: NSColor {
        let text = theme.palette.text
        return NSColor(srgbRed: text.red, green: text.green, blue: text.blue, alpha: Self.barTrackOpacity)
    }

    static let barTrackOpacity = 0.18

    func effective(_ base: HexColor, opacity: Double = 1, for use: ContrastCorrection.Use) -> RGB {
        let panel = theme.palette.panel.rgb
        let mixed = HexColor(rgb: RGB(
            red: opacity * base.red + (1 - opacity) * panel.red,
            green: opacity * base.green + (1 - opacity) * panel.green,
            blue: opacity * base.blue + (1 - opacity) * panel.blue
        ))
        guard theme.palette.source == .automatic else { return mixed.rgb }
        return ContrastCorrection.corrected(mixed, against: theme.palette.panel, for: use).rgb
    }

    var scrimRGB: RGB {
        guard hasLightText else { return RGB(red: 1, green: 1, blue: 1) }
        return theme.palette.panel.rgb.brightness < 0.2 ? theme.palette.panel.rgb : RGB(red: 0, green: 0, blue: 0)
    }

    var scrimColor: Color {
        Color(.sRGB, red: scrimRGB.red, green: scrimRGB.green, blue: scrimRGB.blue)
    }


    func titleFont(_ size: CGFloat) -> Font {
        font(size: size, weight: theme.typography.titleWeight.fontWeight)
    }

    func bodyFont(_ size: CGFloat) -> Font {
        font(size: size, weight: .medium)
    }

    func numericFont(_ size: CGFloat) -> Font {
        font(size: size, weight: .medium).monospacedDigit()
    }

    private func font(size: CGFloat, weight: Font.Weight) -> Font {
        if let family = theme.typography.family, NSFontManager.shared.availableMembers(ofFontFamily: family) != nil {
            return Font.custom(family, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: theme.typography.design.fontDesign)
    }

    @MainActor
    public static func resolve(_ theme: Theme, in store: ThemeStore) -> ThemeAppearance {
        let background = theme.background.map {
            MediaSource(url: store.mediaURL(themeID: theme.id, media: $0.media), kind: $0.media.kind)
        }
        return ThemeAppearance(theme: theme, background: background, measurement: store.measurement(themeID: theme.id))
    }
}

extension Color {
    init(_ hex: HexColor) {
        self.init(.sRGB, red: hex.red, green: hex.green, blue: hex.blue, opacity: hex.alpha)
    }
}

extension FontDesign {
    var fontDesign: Font.Design {
        switch self {
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }
}

extension FontWeightName {
    var fontWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

private struct ThemeAppearanceKey: EnvironmentKey {
    static let defaultValue = ThemeAppearance(theme: .notchyDefault, background: nil)
}

extension EnvironmentValues {
    var themeAppearance: ThemeAppearance {
        get { self[ThemeAppearanceKey.self] }
        set { self[ThemeAppearanceKey.self] = newValue }
    }
}
