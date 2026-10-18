import Foundation

public enum PaletteSource: String, Codable, Sendable {
    case automatic
    case manual
}

public struct ThemePalette: Codable, Equatable, Sendable {
    public var accent: HexColor
    public var secondary: HexColor
    public var panel: HexColor
    public var text: HexColor
    public var source: PaletteSource
}

public enum FontDesign: String, Codable, CaseIterable, Sendable {
    case system, rounded, serif, monospaced
}

public enum FontWeightName: String, Codable, CaseIterable, Sendable {
    case regular, medium, semibold, bold, heavy, black
}

public struct ThemeTypography: Codable, Equatable, Sendable {
    public var design: FontDesign
    public var family: String?
    public var titleWeight: FontWeightName
    public var labelTracking: Double

    public static let standard = ThemeTypography(design: .rounded, family: nil, titleWeight: .semibold, labelTracking: 2.2)

    func sanitized() -> ThemeTypography {
        var copy = self
        copy.labelTracking = labelTracking.clamped(to: 0...8)
        copy.family = family.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : String($0.prefix(80)) }
        return copy
    }
}

public struct ThemeShape: Codable, Equatable, Sendable {
    public static let widthRange: ClosedRange<Double> = 2.0...3.2
    public static let bodyRange: ClosedRange<Double> = 3.4...5.0
    public static let radiusRange: ClosedRange<Double> = 0...1
    public static let junctionRange: ClosedRange<Double> = 0...0.45

    public var widthRatio: Double
    public var bodyRatio: Double
    public var bodyTopRadiusRatio: Double
    public var bottomRadiusRatio: Double
    public var junctionRatio: Double

    public static let standard = ThemeShape(
        widthRatio: 2.4, bodyRatio: 3.6, bodyTopRadiusRatio: 0.48, bottomRadiusRatio: 0.7, junctionRatio: 0.3
    )

    public init(widthRatio: Double, bodyRatio: Double, bodyTopRadiusRatio: Double, bottomRadiusRatio: Double, junctionRatio: Double) {
        self.widthRatio = widthRatio
        self.bodyRatio = bodyRatio
        self.bodyTopRadiusRatio = bodyTopRadiusRatio
        self.bottomRadiusRatio = bottomRadiusRatio
        self.junctionRatio = junctionRatio
    }

    private enum CodingKeys: String, CodingKey {
        case widthRatio, bodyRatio, bodyTopRadiusRatio, bottomRadiusRatio, junctionRatio
        case expandedWidth, expandedHeight, bodyTopRadius, bottomRadius, junctionRadius
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.standard
        let notch = IslandLayout.referenceNotch

        func value(_ key: CodingKeys, legacy: CodingKeys, convert: (Double) -> Double, default def: Double) throws -> Double {
            if let current = try container.decodeIfPresent(Double.self, forKey: key) { return current }
            if let old = try container.decodeIfPresent(Double.self, forKey: legacy) { return convert(old) }
            return def
        }

        widthRatio = try value(.widthRatio, legacy: .expandedWidth, convert: { $0 / notch.width }, default: fallback.widthRatio)
        bodyRatio = try value(.bodyRatio, legacy: .expandedHeight, convert: { ($0 - notch.height) / notch.height }, default: fallback.bodyRatio)
        bodyTopRadiusRatio = try value(.bodyTopRadiusRatio, legacy: .bodyTopRadius, convert: { $0 / notch.height }, default: fallback.bodyTopRadiusRatio)
        bottomRadiusRatio = try value(.bottomRadiusRatio, legacy: .bottomRadius, convert: { $0 / notch.height }, default: fallback.bottomRadiusRatio)
        junctionRatio = try value(.junctionRatio, legacy: .junctionRadius, convert: { $0 / notch.height }, default: fallback.junctionRatio)
        self = sanitized()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(widthRatio, forKey: .widthRatio)
        try container.encode(bodyRatio, forKey: .bodyRatio)
        try container.encode(bodyTopRadiusRatio, forKey: .bodyTopRadiusRatio)
        try container.encode(bottomRadiusRatio, forKey: .bottomRadiusRatio)
        try container.encode(junctionRatio, forKey: .junctionRatio)
    }

    public func sanitized() -> ThemeShape {
        ThemeShape(
            widthRatio: widthRatio.clamped(to: Self.widthRange),
            bodyRatio: bodyRatio.clamped(to: Self.bodyRange),
            bodyTopRadiusRatio: bodyTopRadiusRatio.clamped(to: Self.radiusRange),
            bottomRadiusRatio: bottomRadiusRatio.clamped(to: Self.radiusRange),
            junctionRatio: junctionRatio.clamped(to: Self.junctionRange)
        )
    }
}

public enum OpenAnimation: String, Codable, CaseIterable, Sendable {
    case spring, bouncy, smooth, fade, glitch, gate, menacing, slash, orbit
}

public enum ThemeEmblem: String, Codable, CaseIterable, Sendable {
    case nixieTube, crossedBlades, menacingGlyph, katana, astrolabe
    case coffeeCup, tacticalMap, grimoire, sealedFinger, chainsaw, pocketWatch
    case staffAndFlowers, strawHat, kunai, typewriter, percentMeter
}

public enum ThemeDecoration: String, Codable, CaseIterable, Sendable {
    case nixieTerminal
    case wallPlating
    case menacing
    case reiatsu
    case orbits
    case cracks
    case tacticalGrid
    case clovers
    case cursedWisps
    case sawTeeth
    case transmutation
    case petals
    case waves
    case spiral
    case stationery
    case psychicRings
}

public struct ThemeEffects: Codable, Equatable, Sendable {
    public var glow: Double
    public var borderWidth: Double

    public static let standard = ThemeEffects(glow: 0.25, borderWidth: 0)

    func sanitized() -> ThemeEffects {
        ThemeEffects(glow: glow.clamped(to: 0...1), borderWidth: borderWidth.clamped(to: 0...3))
    }
}

public enum MediaKind: String, Codable, Sendable {
    case image, animatedImage, video
}

public struct ThemeMedia: Codable, Equatable, Sendable {
    public var kind: MediaKind
    public var file: String
    public var crop: MediaCrop

    public static func isSafeFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix(".") && !name.contains("/") && !name.contains("\\") && name.count <= 120
    }
}

public struct ThemeBackground: Codable, Equatable, Sendable {
    public static let legibilityRange: ClosedRange<Double> = 0.55...0.9
    public static let defaultLegibility = 0.65

    public var media: ThemeMedia
    public var legibility: Double

    public init(media: ThemeMedia, legibility: Double) {
        self.media = media
        self.legibility = legibility
    }

    private enum CodingKeys: String, CodingKey {
        case media, legibility
        case legacyDim = "dim"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        media = try container.decode(ThemeMedia.self, forKey: .media)
        let raw = try container.decodeIfPresent(Double.self, forKey: .legibility)
            ?? container.decodeIfPresent(Double.self, forKey: .legacyDim)
            ?? Self.defaultLegibility
        legibility = raw.clamped(to: Self.legibilityRange)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(media, forKey: .media)
        try container.encode(legibility, forKey: .legibility)
    }
}

public struct Theme: Codable, Equatable, Identifiable, Sendable {
    public static let schemaVersion = 1

    public var id: String
    public var name: String
    public var palette: ThemePalette
    public var typography: ThemeTypography
    public var shape: ThemeShape
    public var openAnimation: OpenAnimation
    public var effects: ThemeEffects
    public var background: ThemeBackground?
    public var decoration: ThemeDecoration?
    public var emblem: ThemeEmblem?

    public init(
        id: String, name: String, palette: ThemePalette, typography: ThemeTypography, shape: ThemeShape,
        openAnimation: OpenAnimation, effects: ThemeEffects, background: ThemeBackground?,
        decoration: ThemeDecoration? = nil,
        emblem: ThemeEmblem? = nil
    ) {
        self.id = id
        self.name = name
        self.palette = palette
        self.typography = typography
        self.shape = shape
        self.openAnimation = openAnimation
        self.effects = effects
        self.background = background
        self.decoration = decoration
        self.emblem = emblem
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, palette, typography, shape, openAnimation, effects, background, decoration, emblem
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Theme.notchyDefault
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? String(localized: "Sin nombre")
        palette = try container.decodeIfPresent(ThemePalette.self, forKey: .palette) ?? fallback.palette
        typography = try container.decodeIfPresent(ThemeTypography.self, forKey: .typography) ?? fallback.typography
        shape = try container.decodeIfPresent(ThemeShape.self, forKey: .shape) ?? fallback.shape
        openAnimation = (try? container.decodeIfPresent(OpenAnimation.self, forKey: .openAnimation)) ?? fallback.openAnimation
        effects = try container.decodeIfPresent(ThemeEffects.self, forKey: .effects) ?? fallback.effects
        background = try container.decodeIfPresent(ThemeBackground.self, forKey: .background)
        decoration = try? container.decodeIfPresent(ThemeDecoration.self, forKey: .decoration)
        emblem = try? container.decodeIfPresent(ThemeEmblem.self, forKey: .emblem)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(palette, forKey: .palette)
        try container.encode(typography, forKey: .typography)
        try container.encode(shape, forKey: .shape)
        try container.encode(openAnimation, forKey: .openAnimation)
        try container.encode(effects, forKey: .effects)
        try container.encodeIfPresent(background, forKey: .background)
        try container.encodeIfPresent(decoration, forKey: .decoration)
        try container.encodeIfPresent(emblem, forKey: .emblem)
    }

    public func sanitized() -> Theme {
        var copy = self
        copy.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        if copy.name.isEmpty { copy.name = String(localized: "Sin nombre") }
        copy.typography = typography.sanitized()
        copy.shape = shape.sanitized()
        copy.effects = effects.sanitized()
        if var background {
            background.legibility = background.legibility.clamped(to: ThemeBackground.legibilityRange)
            background.media.crop = background.media.crop.sanitized()
            copy.background = ThemeMedia.isSafeFileName(background.media.file) ? background : nil
        }
        return copy
    }
}

extension Theme {
    public static let notchyDefault = Theme(
        id: "notchy",
        name: "Notchy",
        palette: ThemePalette(
            accent: HexColor("#FF6B1A")!,
            secondary: HexColor("#FFB347")!,
            panel: HexColor("#000000")!,
            text: HexColor("#FFFFFF")!,
            source: .manual
        ),
        typography: .standard,
        shape: .standard,
        openAnimation: .spring,
        effects: .standard,
        background: nil
    )
}
