import CoreGraphics

enum FramingAdvice {
    static let heavyVeil = 0.7

    static func needsDarkerArea(measurement: BackgroundMeasurement, crop: MediaCrop, theme: Theme) -> Bool {
        let layout = IslandLayout(notch: IslandLayout.referenceNotch, stemHeight: nil, shape: theme.shape)
        let size = CGSize(width: layout.size.width, height: layout.bodyHeight)
        guard size.width > 0, size.height > 0 else { return false }
        let appearance = ThemeAppearance(theme: theme, background: nil, measurement: measurement)
        let textStart = (layout.padding + layout.artworkSide + layout.columnGap) / size.width
        let textEnd = min(textStart + layout.textWidth / size.width, 1)
        let zone = ScrimZone(
            horizontal: Double(textStart)...Double(textEnd),
            vertical: 0...1,
            foregrounds: ScrimPlan.foregrounds(for: .text, appearance: appearance)
        )
        let framed = measurement.sample.framed(crop: crop, targetAspect: size.width / size.height)
        return LegibilityPlanner.strength(for: zone, over: framed, scrim: appearance.scrimRGB, atLeast: 0) > heavyVeil
    }
}
