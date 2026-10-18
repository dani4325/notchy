import Foundation

extension Theme {
    public static let steinsGate = Theme(
        id: "builtin-steins-gate",
        name: "Steins;Gate",
        palette: ThemePalette(
            accent: HexColor("#39FF88")!, secondary: HexColor("#FF8A2A")!,
            panel: HexColor("#040A06")!, text: HexColor("#D6FFE4")!, source: .manual
        ),
        typography: ThemeTypography(design: .monospaced, family: "Share Tech Mono", titleWeight: .regular, labelTracking: 3),
        shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.7, bodyTopRadiusRatio: 0.28, bottomRadiusRatio: 0.42, junctionRatio: 0.24),
        openAnimation: .glitch,
        effects: ThemeEffects(glow: 0.45, borderWidth: 0.75),
        background: nil,
        decoration: .nixieTerminal,
        emblem: .nixieTube
    )

    public static let attackOnTitan = Theme(
        id: "builtin-attack-on-titan",
        name: "Attack on Titan",
        palette: ThemePalette(
            accent: HexColor("#C9A35E")!, secondary: HexColor("#8E5B34")!,
            panel: HexColor("#2A2119")!, text: HexColor("#EFE5D0")!, source: .manual
        ),
        typography: ThemeTypography(design: .system, family: "Big Shoulders Stencil Display", titleWeight: .bold, labelTracking: 3.2),
        shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.7, bodyTopRadiusRatio: 0.14, bottomRadiusRatio: 0.26, junctionRatio: 0.18),
        openAnimation: .gate,
        effects: ThemeEffects(glow: 0.15, borderWidth: 1.5),
        background: nil,
        decoration: .wallPlating,
        emblem: .crossedBlades
    )

    public static let jojo = Theme(
        id: "builtin-jojo",
        name: "JoJo's Bizarre Adventure",
        palette: ThemePalette(
            accent: HexColor("#F5C518")!, secondary: HexColor("#E0218A")!,
            panel: HexColor("#2A0B3D")!, text: HexColor("#FFF4D6")!, source: .manual
        ),
        typography: ThemeTypography(design: .rounded, family: "Dela Gothic One", titleWeight: .regular, labelTracking: 1.6),
        shape: ThemeShape(widthRatio: 2.55, bodyRatio: 3.7, bodyTopRadiusRatio: 0.36, bottomRadiusRatio: 0.55, junctionRatio: 0.3),
        openAnimation: .menacing,
        effects: ThemeEffects(glow: 0.55, borderWidth: 1),
        background: nil,
        decoration: .menacing,
        emblem: .menacingGlyph
    )

    public static let bleach = Theme(
        id: "builtin-bleach",
        name: "Bleach",
        palette: ThemePalette(
            accent: HexColor("#E23B3B")!, secondary: HexColor("#8FD3FF")!,
            panel: HexColor("#0A0A0C")!, text: HexColor("#F5F5F7")!, source: .manual
        ),
        typography: ThemeTypography(design: .system, family: "Bebas Neue", titleWeight: .regular, labelTracking: 4),
        shape: ThemeShape(widthRatio: 2.45, bodyRatio: 3.6, bodyTopRadiusRatio: 0.2, bottomRadiusRatio: 0.34, junctionRatio: 0.22),
        openAnimation: .slash,
        effects: ThemeEffects(glow: 0.35, borderWidth: 0),
        background: nil,
        decoration: .reiatsu,
        emblem: .katana
    )

    public static let orb = Theme(
        id: "builtin-orb",
        name: "Orb: On the Movements of the Earth",
        palette: ThemePalette(
            accent: HexColor("#D9B15C")!, secondary: HexColor("#7FA3D6")!,
            panel: HexColor("#0C1428")!, text: HexColor("#F3E9D2")!, source: .manual
        ),
        typography: ThemeTypography(design: .serif, family: "Cormorant Garamond", titleWeight: .semibold, labelTracking: 2.4),
        shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.8, bodyTopRadiusRatio: 0.5, bottomRadiusRatio: 0.75, junctionRatio: 0.32),
        openAnimation: .orbit,
        effects: ThemeEffects(glow: 0.3, borderWidth: 0.75),
        background: nil,
        decoration: .orbits,
        emblem: .astrolabe
    )

    public static let tokyoGhoul = template(
        "tokyo-ghoul", "Tokyo Ghoul", colors: ("#E0142B", "#F2F2F2", "#0B0B0D", "#EDEDED"),
        font: "Bebas Neue", design: .system, weight: .regular, tracking: 4,
        shape: (2.45, 3.6, 0.18, 0.3, 0.2), open: .slash, glow: 0.4, border: 0.75, decoration: .cracks, emblem: .coffeeCup
    )

    public static let eightySix = template(
        "eighty-six", "86 Eighty-Six", colors: ("#E8C547", "#7FBF7F", "#0E1512", "#DDE6DF"),
        font: "Share Tech Mono", design: .monospaced, weight: .regular, tracking: 2.6,
        shape: (2.5, 3.6, 0.12, 0.22, 0.16), open: .smooth, glow: 0.2, border: 1, decoration: .tacticalGrid, emblem: .tacticalMap
    )

    public static let blackClover = template(
        "black-clover", "Black Clover", colors: ("#2FBF71", "#E4D7A6", "#0B1A12", "#F1EEDD"),
        font: "Cormorant Garamond", design: .serif, weight: .bold, tracking: 2.2,
        shape: (2.5, 3.7, 0.4, 0.6, 0.28), open: .bouncy, glow: 0.35, border: 1, decoration: .clovers, emblem: .grimoire
    )

    public static let jujutsuKaisen = template(
        "jujutsu-kaisen", "Jujutsu Kaisen", colors: ("#7A5CFF", "#2DE2E6", "#0A0714", "#ECE8FF"),
        font: "Dela Gothic One", design: .rounded, weight: .regular, tracking: 1.4,
        shape: (2.5, 3.7, 0.3, 0.48, 0.26), open: .glitch, glow: 0.5, border: 0.75, decoration: .cursedWisps, emblem: .sealedFinger
    )

    public static let chainsawMan = template(
        "chainsaw-man", "Chainsaw Man", colors: ("#FF7A1A", "#F2D7A0", "#1A0E07", "#FFF1E0"),
        font: "Dela Gothic One", design: .rounded, weight: .regular, tracking: 1.4,
        shape: (2.5, 3.7, 0.38, 0.6, 0.3), open: .bouncy, glow: 0.45, border: 1, decoration: .sawTeeth, emblem: .chainsaw
    )

    public static let fullmetalAlchemist = template(
        "fullmetal-alchemist", "Fullmetal Alchemist", colors: ("#D4A017", "#B22222", "#1B0F0A", "#F5E6C8"),
        font: "Cormorant Garamond", design: .serif, weight: .bold, tracking: 2.4,
        shape: (2.5, 3.7, 0.3, 0.5, 0.26), open: .orbit, glow: 0.3, border: 1, decoration: .transmutation, emblem: .pocketWatch
    )

    public static let frieren = template(
        "frieren", "Frieren: Beyond Journey's End", colors: ("#9ED8C6", "#D9C7F2", "#0D1418", "#F1F5F4"),
        font: "Cormorant Garamond", design: .serif, weight: .semibold, tracking: 2.2,
        shape: (2.5, 3.8, 0.55, 0.8, 0.34), open: .smooth, glow: 0.3, border: 0.5, decoration: .petals, emblem: .staffAndFlowers
    )

    public static let onePiece = template(
        "one-piece", "One Piece", colors: ("#F2C14E", "#D62828", "#0A1E33", "#FFF6E5"),
        font: "Bebas Neue", design: .system, weight: .regular, tracking: 3,
        shape: (2.5, 3.7, 0.4, 0.62, 0.3), open: .bouncy, glow: 0.35, border: 1, decoration: .waves, emblem: .strawHat
    )

    public static let naruto = template(
        "naruto", "Naruto", colors: ("#FF8C1A", "#3D6FD1", "#140D07", "#FFF2E0"),
        font: "Big Shoulders Stencil Display", design: .system, weight: .heavy, tracking: 2.6,
        shape: (2.5, 3.7, 0.26, 0.42, 0.24), open: .spring, glow: 0.35, border: 1, decoration: .spiral, emblem: .kunai
    )

    public static let violetEvergarden = template(
        "violet-evergarden", "Violet Evergarden", colors: ("#E8D3A8", "#7FA7D9", "#121826", "#F6F1E7"),
        font: "Cormorant Garamond", design: .serif, weight: .medium, tracking: 2.6,
        shape: (2.5, 3.8, 0.5, 0.75, 0.34), open: .fade, glow: 0.25, border: 0.5, decoration: .stationery, emblem: .typewriter
    )

    public static let mobPsycho = template(
        "mob-psycho", "Mob Psycho 100", colors: ("#8CF55B", "#FF5BC8", "#120A1C", "#F9F7FF"),
        font: "Dela Gothic One", design: .rounded, weight: .regular, tracking: 1.4,
        shape: (2.5, 3.7, 0.42, 0.62, 0.3), open: .spring, glow: 0.5, border: 0.75, decoration: .psychicRings, emblem: .percentMeter
    )

    public static let builtIns: [Theme] = [
        .steinsGate, .attackOnTitan, .jojo, .bleach, .orb,
        .tokyoGhoul, .eightySix, .blackClover, .jujutsuKaisen, .chainsawMan, .fullmetalAlchemist,
        .frieren, .onePiece, .naruto, .violetEvergarden, .mobPsycho,
    ]

    private static func template(
        _ slug: String, _ name: String,
        colors: (accent: String, secondary: String, panel: String, text: String),
        font: String, design: FontDesign, weight: FontWeightName, tracking: Double,
        shape: (width: Double, body: Double, top: Double, bottom: Double, junction: Double),
        open: OpenAnimation, glow: Double, border: Double, decoration: ThemeDecoration, emblem: ThemeEmblem
    ) -> Theme {
        Theme(
            id: "builtin-\(slug)",
            name: name,
            palette: ThemePalette(
                accent: HexColor(colors.accent)!, secondary: HexColor(colors.secondary)!,
                panel: HexColor(colors.panel)!, text: HexColor(colors.text)!, source: .manual
            ),
            typography: ThemeTypography(design: design, family: font, titleWeight: weight, labelTracking: tracking),
            shape: ThemeShape(
                widthRatio: shape.width, bodyRatio: shape.body, bodyTopRadiusRatio: shape.top,
                bottomRadiusRatio: shape.bottom, junctionRatio: shape.junction
            ),
            openAnimation: open,
            effects: ThemeEffects(glow: glow, borderWidth: border),
            background: nil,
            decoration: decoration,
            emblem: emblem
        )
    }
}
