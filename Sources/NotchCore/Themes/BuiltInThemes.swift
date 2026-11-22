import Foundation

extension Theme {
    public static let cartel = Theme(
        id: "builtin-cartel",
        name: String(localized: "Cartel"),
        palette: ThemePalette(
            accent: HexColor("#C21F18")!, secondary: HexColor("#555555")!,
            panel: HexColor("#F2F2F2")!, text: HexColor("#111111")!, source: .manual
        ),
        typography: ThemeTypography(design: .system, family: "Big Shoulders Display", titleWeight: .heavy, labelTracking: 2),
        shape: ThemeShape(widthRatio: 2.45, bodyRatio: 3.6, bodyTopRadiusRatio: 0.08, bottomRadiusRatio: 0.12, junctionRatio: 0.12),
        openAnimation: .cut,
        effects: ThemeEffects(glow: 0, borderWidth: 0),
        background: nil,
        decoration: .zigzag
    )

    public static let fosforo = Theme(
        id: "builtin-fosforo",
        name: String(localized: "Fósforo"),
        palette: ThemePalette(
            accent: HexColor("#39E07A")!, secondary: HexColor("#2FA35E")!,
            panel: HexColor("#000000")!, text: HexColor("#D9F7E3")!, source: .manual
        ),
        typography: ThemeTypography(design: .monospaced, family: "Share Tech Mono", titleWeight: .regular, labelTracking: 2),
        shape: ThemeShape(widthRatio: 2.45, bodyRatio: 3.6, bodyTopRadiusRatio: 0.3, bottomRadiusRatio: 0.42, junctionRatio: 0.24),
        openAnimation: .glitch,
        effects: ThemeEffects(glow: 0.35, borderWidth: 0),
        background: nil,
        decoration: .scanlines
    )

    public static let caratula = Theme(
        id: "builtin-caratula",
        name: String(localized: "Carátula"),
        palette: Theme.notchyDefault.palette,
        typography: .standard,
        shape: .standard,
        openAnimation: .smooth,
        effects: ThemeEffects(glow: 0, borderWidth: 0),
        background: nil,
        usesArtwork: true
    )

    public static let builtIns: [Theme] = [.notchyDefault, .cartel, .fosforo, .caratula]
}
