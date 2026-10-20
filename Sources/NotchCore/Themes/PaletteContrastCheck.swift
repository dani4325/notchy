import Foundation

struct PaletteContrastIssue: Equatable, Sendable {
    enum Role: Hashable, Sendable {
        case accent
        case secondary
        case text
    }

    let role: Role
    let ratio: Double
    let failsText: Bool
    let failsGraphic: Bool
    let corrected: HexColor
}

enum PaletteContrastCheck {
    private static let textTargetStep = 0.25
    private static let maximumRatio = 21.0

    static func issues(in palette: ThemePalette) -> [PaletteContrastIssue] {
        guard palette.source == .manual else { return [] }
        return [
            colorIssue(.accent, palette.accent, panel: palette.panel),
            colorIssue(.secondary, palette.secondary, panel: palette.panel),
            textIssue(palette.text, panel: palette.panel),
        ].compactMap { $0 }
    }

    static func mixed(_ color: HexColor, over panel: HexColor, opacity: Double) -> HexColor {
        HexColor(rgb: RGB(
            red: opacity * color.red + (1 - opacity) * panel.red,
            green: opacity * color.green + (1 - opacity) * panel.green,
            blue: opacity * color.blue + (1 - opacity) * panel.blue
        ))
    }

    private static func colorIssue(_ role: PaletteContrastIssue.Role, _ color: HexColor, panel: HexColor) -> PaletteContrastIssue? {
        let ratio = color.contrastRatio(with: panel)
        guard ratio < ContrastCorrection.Use.text.minimumRatio else { return nil }
        return PaletteContrastIssue(
            role: role, ratio: ratio,
            failsText: true, failsGraphic: ratio < ContrastCorrection.Use.graphic.minimumRatio,
            corrected: ContrastCorrection.corrected(color, against: panel, for: .text)
        )
    }

    private static func textIssue(_ text: HexColor, panel: HexColor) -> PaletteContrastIssue? {
        let opacity = ThemeAppearance.secondaryTextOpacity
        let minimum = ContrastCorrection.Use.text.minimumRatio
        let ratio = mixed(text, over: panel, opacity: opacity).contrastRatio(with: panel)
        guard ratio < minimum else { return nil }
        var target = minimum
        var corrected = ContrastCorrection.corrected(text, against: panel, minimum: target)
        while mixed(corrected, over: panel, opacity: opacity).contrastRatio(with: panel) < minimum, target < maximumRatio {
            target += textTargetStep
            corrected = ContrastCorrection.corrected(text, against: panel, minimum: target)
        }
        return PaletteContrastIssue(
            role: .text, ratio: ratio,
            failsText: true, failsGraphic: text.contrastRatio(with: panel) < ContrastCorrection.Use.graphic.minimumRatio,
            corrected: corrected
        )
    }
}
