import SwiftUI

struct ScrimPlan: Equatable, Sendable {
    let boundaries: [Double]
    let strengths: [Double]

    static let ramp = 0.1
    static let textOpacities = [1.0, ThemeAppearance.secondaryTextOpacity]

    static func zones(layout: IslandLayout, appearance: ThemeAppearance, coversWholeWidth: Bool) -> (boundaries: [Double], zones: [ScrimZone]) {
        let palette = appearance.theme.palette
        let text = textOpacities.map { ScrimZone.Foreground(color: palette.text.rgb, opacity: $0, use: .text) }
        let accent = [
            ScrimZone.Foreground(color: appearance.effective(palette.accent, for: .text), opacity: 1, use: .text),
            ScrimZone.Foreground(color: appearance.effective(palette.accent, for: .graphic), opacity: 1, use: .graphic),
            ScrimZone.Foreground(color: appearance.effective(palette.secondary, for: .graphic), opacity: 1, use: .graphic),
        ]
        let icons = [ScrimZone.Foreground(color: palette.text.rgb, opacity: 1, use: .graphic)]
        if coversWholeWidth {
            return ([], [ScrimZone(horizontal: 0...1, vertical: 0...1, foregrounds: text + accent + icons)])
        }
        let width = max(layout.size.width, 1)
        let textStart = min(max((layout.padding + layout.artworkSide + layout.columnGap) / width, 0), 1)
        let textEnd = min(max(textStart + layout.textWidth / width, textStart), 1)
        return ([textStart, textEnd], [
            ScrimZone(horizontal: 0...textStart, vertical: 0...1, foregrounds: accent + icons),
            ScrimZone(horizontal: textStart...textEnd, vertical: 0...1, foregrounds: text + accent),
            ScrimZone(horizontal: textEnd...1, vertical: 0...1, foregrounds: icons),
        ])
    }

    static func make(_ sample: FramedSample, layout: IslandLayout, appearance: ThemeAppearance, minimum: Double, coversWholeWidth: Bool) -> ScrimPlan {
        let (boundaries, zones) = zones(layout: layout, appearance: appearance, coversWholeWidth: coversWholeWidth)
        let strengths = zones.map {
            LegibilityPlanner.strength(for: $0, over: sample, scrim: appearance.scrimRGB, atLeast: minimum)
        }
        return ScrimPlan(boundaries: boundaries, strengths: strengths)
    }
}

struct LegibilityScrim: View {
    let appearance: ThemeAppearance
    let layout: IslandLayout
    let crop: MediaCrop
    let minimum: Double
    let coversWholeWidth: Bool
    let size: CGSize

    var body: some View {
        let color = appearance.scrimColor
        if let measurement = appearance.measurement, size.width > 0, size.height > 0 {
            let plan = ScrimPlanCache.plan(
                for: measurement, crop: crop, size: size, layout: layout, appearance: appearance,
                minimum: minimum, coversWholeWidth: coversWholeWidth
            )
            let stops = LegibilityPlanner.stops(boundaries: plan.boundaries, strengths: plan.strengths, ramp: ScrimPlan.ramp)
            LinearGradient(
                stops: stops.map { Gradient.Stop(color: color.opacity($0.value), location: $0.location) },
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            color
        }
    }
}

@MainActor
enum ScrimPlanCache {
    private struct Key: Hashable {
        let themeID: String
        let mediaFile: String
        let crop: MediaCrop
        let width: Int
        let height: Int
        let palette: [HexColor]
        let textStart: Int
        let textEnd: Int
        let minimum: Double
        let coversWholeWidth: Bool
    }

    private static let retained = 16
    private static var plans: [Key: ScrimPlan] = [:]
    private static var order: [Key] = []

    static func plan(for measurement: BackgroundMeasurement, crop: MediaCrop, size: CGSize, layout: IslandLayout, appearance: ThemeAppearance, minimum: Double, coversWholeWidth: Bool) -> ScrimPlan {
        let palette = appearance.theme.palette
        let key = Key(
            themeID: appearance.theme.id,
            mediaFile: appearance.theme.background?.media.file ?? "",
            crop: crop,
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            palette: [palette.text, palette.accent, palette.secondary, palette.panel],
            textStart: Int((layout.padding + layout.artworkSide + layout.columnGap).rounded()),
            textEnd: Int(layout.textWidth.rounded()),
            minimum: minimum,
            coversWholeWidth: coversWholeWidth
        )
        if let cached = plans[key] { return cached }
        let framed = measurement.sample.framed(crop: crop, targetAspect: size.width / size.height)
        let plan = ScrimPlan.make(framed, layout: layout, appearance: appearance, minimum: minimum, coversWholeWidth: coversWholeWidth)
        plans[key] = plan
        order.append(key)
        if order.count > retained { plans[order.removeFirst()] = nil }
        return plan
    }
}
