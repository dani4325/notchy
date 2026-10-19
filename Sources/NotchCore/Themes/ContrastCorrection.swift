import Foundation

enum ContrastCorrection {
    enum Use: CaseIterable, Sendable {
        case text
        case graphic

        var minimumRatio: Double {
            switch self {
            case .text: 4.5
            case .graphic: 3
            }
        }
    }

    private static let lightnessPrecision = 1e-4
    private static let roundingStep = 0.002

    static func corrected(_ color: HexColor, against panel: HexColor, for use: Use) -> HexColor {
        guard color.contrastRatio(with: panel) < use.minimumRatio else { return color }
        return HexColor(rgb: correctedOKLCH(color, against: panel, for: use).rgb)
    }

    static func correctedOKLCH(_ color: HexColor, against panel: HexColor, for use: Use) -> OKLCH {
        let original = OKLCH(color.rgb)
        let minimum = use.minimumRatio
        guard color.contrastRatio(with: panel) < minimum else { return original }
        let preferred: Double = OKLCH(panel.rgb).lightness < original.lightness ? 1 : 0
        let directions = original.lightness == OKLCH(panel.rgb).lightness ? [1.0, 0.0] : [preferred, 1 - preferred]
        for limit in directions {
            if let found = closestPassing(original, toward: limit, against: panel, minimum: minimum) {
                return found
            }
        }
        return OKLCH(lightness: OKLCH(panel.rgb).lightness < 0.5 ? 1 : 0, chroma: 0, hue: original.hue)
    }

    private static func closestPassing(_ original: OKLCH, toward limit: Double, against panel: HexColor, minimum: Double) -> OKLCH? {
        let candidate = { (lightness: Double) in
            OKLCH(lightness: lightness, chroma: original.chroma, hue: original.hue).mappedIntoSRGB()
        }
        let passes = { (lightness: Double) in
            HexColor(rgb: candidate(lightness).rgb).contrastRatio(with: panel) >= minimum
        }
        guard passes(limit) else { return nil }

        var near = original.lightness, far = limit
        while abs(far - near) > lightnessPrecision {
            let middle = (near + far) / 2
            if passes(middle) { far = middle } else { near = middle }
        }
        var lightness = far
        let step = limit > original.lightness ? roundingStep : -roundingStep
        while !passes(lightness) {
            lightness = min(max(lightness + step, 0), 1)
        }
        return candidate(lightness)
    }
}
