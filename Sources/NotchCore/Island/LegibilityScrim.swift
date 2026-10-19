import SwiftUI

struct ScrimPlan: Equatable, Sendable {
    let boundaries: [Double]
    let strengths: [Double]

    static let ramp = 0.1
    static let textOpacities = [1.0, 0.6]

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

    static func make(_ measurement: BackgroundMeasurement, layout: IslandLayout, appearance: ThemeAppearance, minimum: Double, coversWholeWidth: Bool) -> ScrimPlan {
        let (boundaries, zones) = zones(layout: layout, appearance: appearance, coversWholeWidth: coversWholeWidth)
        let strengths = zones.map {
            LegibilityPlanner.strength(for: $0, over: measurement.sample, scrim: appearance.scrimRGB, atLeast: minimum)
        }
        return ScrimPlan(boundaries: boundaries, strengths: strengths)
    }
}

struct LegibilityScrim: View {
    let appearance: ThemeAppearance
    let layout: IslandLayout
    let source: MediaSource
    let crop: MediaCrop
    let minimum: Double
    let coversWholeWidth: Bool
    let size: CGSize

    var body: some View {
        let measurements = BackgroundMeasurements.shared
        let key = BackgroundMeasurements.key(for: source, crop: crop, size: size, backdrop: ScrimPlan.backdrop)
        let plan = measurements.results[key].map {
            ScrimPlanCache.plan(for: $0, key: key, layout: layout, appearance: appearance, minimum: minimum, coversWholeWidth: coversWholeWidth)
        }
        gradient(plan)
            .task(id: key) { await measurements.measure(key) }
    }

    @ViewBuilder
    private func gradient(_ plan: ScrimPlan?) -> some View {
        let color = appearance.scrimColor
        if let plan {
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

extension ScrimPlan {
    static let backdrop = HexColor("#000000")!
}

@MainActor
enum ScrimPlanCache {
    private struct Key: Hashable {
        let measurement: BackgroundMeasurements.Key
        let palette: [HexColor]
        let scrim: HexColor
        let width: Int
        let textStart: Int
        let textEnd: Int
        let minimum: Double
        let coversWholeWidth: Bool
    }

    private static let retained = 16
    private static var plans: [Key: ScrimPlan] = [:]
    private static var order: [Key] = []

    static func plan(for measurement: BackgroundMeasurement, key measurementKey: BackgroundMeasurements.Key, layout: IslandLayout, appearance: ThemeAppearance, minimum: Double, coversWholeWidth: Bool) -> ScrimPlan {
        let palette = appearance.theme.palette
        let key = Key(
            measurement: measurementKey,
            palette: [palette.text, palette.accent, palette.secondary, palette.panel],
            scrim: HexColor(rgb: appearance.scrimRGB),
            width: Int(layout.size.width.rounded()),
            textStart: Int((layout.padding + layout.artworkSide + layout.columnGap).rounded()),
            textEnd: Int(layout.textWidth.rounded()),
            minimum: minimum,
            coversWholeWidth: coversWholeWidth
        )
        if let cached = plans[key] { return cached }
        let plan = ScrimPlan.make(measurement, layout: layout, appearance: appearance, minimum: minimum, coversWholeWidth: coversWholeWidth)
        plans[key] = plan
        order.append(key)
        if order.count > retained { plans[order.removeFirst()] = nil }
        return plan
    }
}
