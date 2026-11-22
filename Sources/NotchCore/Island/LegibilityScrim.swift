import SwiftUI

enum ScrimPlan {
    static let textOpacities = [1.0, ThemeAppearance.secondaryTextOpacity]

    static func foregrounds(for needs: LegibilityNeeds, appearance: ThemeAppearance) -> [ScrimZone.Foreground] {
        let palette = appearance.theme.palette
        var result: [ScrimZone.Foreground] = []
        if needs.contains(.text) {
            result += textOpacities.map { ScrimZone.Foreground(color: palette.text.rgb, opacity: $0, use: .text) }
            if appearance.hasRetroDigits {
                result.append(ScrimZone.Foreground(color: appearance.effective(palette.accent, for: .text), opacity: 1, use: .text))
            }
        }
        if needs.contains(.graphics) {
            result.append(ScrimZone.Foreground(color: palette.text.rgb, opacity: 1, use: .graphic))
        }
        if needs.contains(.accent) {
            result.append(ScrimZone.Foreground(color: appearance.effective(palette.accent, for: .graphic), opacity: 1, use: .graphic))
        }
        return result
    }
}

struct LegibilityScrim: View {
    static let featherRatio: CGFloat = 0.3
    static let maximumVeil = 0.22

    let appearance: ThemeAppearance
    let layout: IslandLayout
    let crop: MediaCrop
    let minimum: Double
    let size: CGSize
    let marks: [LegibilityMark]

    var body: some View {
        let color = appearance.scrimColor
        if let measurement = appearance.measurement, size.width > 0, size.height > 0 {
            ZStack {
                color.opacity(minimum)
                if let veil = VeilCache.image(
                    for: measurement, crop: crop, size: size, appearance: appearance, marks: marks,
                    minimum: minimum, feather: layout.unit * Self.featherRatio
                ) {
                    Image(decorative: veil, scale: VeilMask.pixelsPerPoint)
                        .resizable()
                        .interpolation(.high)
                }
            }
        } else {
            color
        }
    }
}

@MainActor
enum VeilCache {
    private struct Key: Hashable {
        let themeID: String
        let mediaFile: String
        let crop: MediaCrop
        let width: Int
        let height: Int
        let palette: [HexColor]
        let marks: [MarkKey]
        let minimum: Double
        let feather: Double
    }

    private struct MarkKey: Hashable {
        let needs: Int
        let x: Int, y: Int, width: Int, height: Int

        init(_ mark: LegibilityMark) {
            needs = mark.needs.rawValue
            x = Int(mark.rect.minX.rounded()); y = Int(mark.rect.minY.rounded())
            width = Int(mark.rect.width.rounded()); height = Int(mark.rect.height.rounded())
        }
    }

    private static let retained = 8
    private static var images: [Key: CGImage] = [:]
    private static var order: [Key] = []

    static func spots(for measurement: BackgroundMeasurement, crop: MediaCrop, size: CGSize, appearance: ThemeAppearance, marks: [LegibilityMark], minimum: Double) -> [VeilSpot] {
        let framed = measurement.sample.framed(crop: crop, targetAspect: size.width / size.height)
        return marks.compactMap { mark in
            let rect = mark.rect.intersection(CGRect(origin: .zero, size: size))
            guard !rect.isNull, rect.width > 0, rect.height > 0 else { return nil }
            let zone = ScrimZone(
                horizontal: Double(rect.minX / size.width)...Double(rect.maxX / size.width),
                vertical: Double(rect.minY / size.height)...Double(rect.maxY / size.height),
                foregrounds: ScrimPlan.foregrounds(for: mark.needs, appearance: appearance)
            )
            let needed = LegibilityPlanner.strength(for: zone, over: framed, scrim: appearance.scrimRGB, atLeast: minimum)
            return VeilSpot(rect: rect, strength: max(minimum, min(needed, LegibilityScrim.maximumVeil)))
        }
    }

    static func image(for measurement: BackgroundMeasurement, crop: MediaCrop, size: CGSize, appearance: ThemeAppearance, marks: [LegibilityMark], minimum: Double, feather: CGFloat) -> CGImage? {
        let palette = appearance.theme.palette
        let key = Key(
            themeID: appearance.theme.id, mediaFile: appearance.background?.url.lastPathComponent ?? "", crop: crop,
            width: Int(size.width.rounded()), height: Int(size.height.rounded()),
            palette: [palette.text, palette.accent, palette.panel], marks: marks.map(MarkKey.init),
            minimum: minimum, feather: Double(feather)
        )
        if let cached = images[key] { return cached }
        let spots = spots(for: measurement, crop: crop, size: size, appearance: appearance, marks: marks, minimum: minimum)
        guard let image = VeilMask(size: size, spots: spots, feather: feather).image(color: appearance.scrimRGB) else { return nil }
        images[key] = image
        order.append(key)
        if order.count > retained { images[order.removeFirst()] = nil }
        return image
    }
}
