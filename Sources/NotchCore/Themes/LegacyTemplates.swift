import CryptoKit
import Foundation

enum LegacyTemplates {
    static let migratedName = String(localized: "Mi tema (1.0)")
    static let legacyDefaultID = "notchy"

    static func isLegacy(_ themeID: String) -> Bool {
        themeID.hasPrefix("builtin-") && !Theme.builtIns.contains { $0.id == themeID }
    }

    static func theme(forLegacyID themeID: String) -> Theme {
        let digest = SHA256.hash(data: Data(themeID.utf8)).map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
        var theme = table[String(digest.prefix(16))] ?? Theme.notchyDefault
        theme.name = migratedName
        theme.usesArtwork = false
        return theme
    }

    static var count: Int { table.count }
    static var all: [Theme] { Array(table.values) }

    private static let table: [String: Theme] = [
        "823b6245fdd38e2d": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#39FF88")!, secondary: HexColor("#FF8A2A")!, panel: HexColor("#040A06")!, text: HexColor("#D6FFE4")!, source: .manual),
            typography: ThemeTypography(design: .monospaced, family: "Share Tech Mono", titleWeight: .regular, labelTracking: 3),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.7, bodyTopRadiusRatio: 0.28, bottomRadiusRatio: 0.42, junctionRatio: 0.24),
            openAnimation: .glitch, effects: ThemeEffects(glow: 0.45, borderWidth: 0.75), background: nil,
            decoration: .scanlines
        ),
        "6925b76f38668ee5": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#C9A35E")!, secondary: HexColor("#8E5B34")!, panel: HexColor("#2A2119")!, text: HexColor("#EFE5D0")!, source: .manual),
            typography: ThemeTypography(design: .system, family: "Big Shoulders Display", titleWeight: .bold, labelTracking: 3.2),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.7, bodyTopRadiusRatio: 0.14, bottomRadiusRatio: 0.26, junctionRatio: 0.18),
            openAnimation: .doors, effects: ThemeEffects(glow: 0.15, borderWidth: 1.5), background: nil,
            decoration: .frame
        ),
        "bea7349ccbc7d43e": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#F5C518")!, secondary: HexColor("#E0218A")!, panel: HexColor("#2A0B3D")!, text: HexColor("#FFF4D6")!, source: .manual),
            typography: ThemeTypography(design: .rounded, family: "Dela Gothic One", titleWeight: .regular, labelTracking: 1.6),
            shape: ThemeShape(widthRatio: 2.55, bodyRatio: 3.7, bodyTopRadiusRatio: 0.36, bottomRadiusRatio: 0.55, junctionRatio: 0.3),
            openAnimation: .spring, effects: ThemeEffects(glow: 0.55, borderWidth: 1), background: nil,
            decoration: .stripes
        ),
        "7600a1b08927e99e": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#E23B3B")!, secondary: HexColor("#8FD3FF")!, panel: HexColor("#0A0A0C")!, text: HexColor("#F5F5F7")!, source: .manual),
            typography: ThemeTypography(design: .system, family: "Bebas Neue", titleWeight: .regular, labelTracking: 4),
            shape: ThemeShape(widthRatio: 2.45, bodyRatio: 3.6, bodyTopRadiusRatio: 0.2, bottomRadiusRatio: 0.34, junctionRatio: 0.22),
            openAnimation: .cut, effects: ThemeEffects(glow: 0.35, borderWidth: 0), background: nil,
            decoration: nil
        ),
        "427c946b1d11a73b": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#D9B15C")!, secondary: HexColor("#7FA3D6")!, panel: HexColor("#0C1428")!, text: HexColor("#F3E9D2")!, source: .manual),
            typography: ThemeTypography(design: .serif, family: "Cormorant Garamond", titleWeight: .semibold, labelTracking: 2.4),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.8, bodyTopRadiusRatio: 0.5, bottomRadiusRatio: 0.75, junctionRatio: 0.32),
            openAnimation: .spring, effects: ThemeEffects(glow: 0.3, borderWidth: 0.75), background: nil,
            decoration: nil
        ),
        "e4e8901892356c27": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#E0142B")!, secondary: HexColor("#F2F2F2")!, panel: HexColor("#0B0B0D")!, text: HexColor("#EDEDED")!, source: .manual),
            typography: ThemeTypography(design: .system, family: "Bebas Neue", titleWeight: .regular, labelTracking: 4),
            shape: ThemeShape(widthRatio: 2.45, bodyRatio: 3.6, bodyTopRadiusRatio: 0.18, bottomRadiusRatio: 0.3, junctionRatio: 0.2),
            openAnimation: .cut, effects: ThemeEffects(glow: 0.4, borderWidth: 0.75), background: nil,
            decoration: nil
        ),
        "ec55b9a56fd46496": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#E8C547")!, secondary: HexColor("#7FBF7F")!, panel: HexColor("#0E1512")!, text: HexColor("#DDE6DF")!, source: .manual),
            typography: ThemeTypography(design: .monospaced, family: "Share Tech Mono", titleWeight: .regular, labelTracking: 2.6),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.6, bodyTopRadiusRatio: 0.12, bottomRadiusRatio: 0.22, junctionRatio: 0.16),
            openAnimation: .smooth, effects: ThemeEffects(glow: 0.2, borderWidth: 1), background: nil,
            decoration: .grid
        ),
        "3898031ae15eabfb": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#2FBF71")!, secondary: HexColor("#E4D7A6")!, panel: HexColor("#0B1A12")!, text: HexColor("#F1EEDD")!, source: .manual),
            typography: ThemeTypography(design: .serif, family: "Cormorant Garamond", titleWeight: .bold, labelTracking: 2.2),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.7, bodyTopRadiusRatio: 0.4, bottomRadiusRatio: 0.6, junctionRatio: 0.28),
            openAnimation: .bouncy, effects: ThemeEffects(glow: 0.35, borderWidth: 1), background: nil,
            decoration: nil
        ),
        "8c158938f6e9b70f": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#7A5CFF")!, secondary: HexColor("#2DE2E6")!, panel: HexColor("#0A0714")!, text: HexColor("#ECE8FF")!, source: .manual),
            typography: ThemeTypography(design: .rounded, family: "Dela Gothic One", titleWeight: .regular, labelTracking: 1.4),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.7, bodyTopRadiusRatio: 0.3, bottomRadiusRatio: 0.48, junctionRatio: 0.26),
            openAnimation: .glitch, effects: ThemeEffects(glow: 0.5, borderWidth: 0.75), background: nil,
            decoration: nil
        ),
        "522e13cca294d343": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#FF7A1A")!, secondary: HexColor("#F2D7A0")!, panel: HexColor("#1A0E07")!, text: HexColor("#FFF1E0")!, source: .manual),
            typography: ThemeTypography(design: .rounded, family: "Dela Gothic One", titleWeight: .regular, labelTracking: 1.4),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.7, bodyTopRadiusRatio: 0.38, bottomRadiusRatio: 0.6, junctionRatio: 0.3),
            openAnimation: .bouncy, effects: ThemeEffects(glow: 0.45, borderWidth: 1), background: nil,
            decoration: .zigzag
        ),
        "01d106a1338d6930": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#D4A017")!, secondary: HexColor("#B22222")!, panel: HexColor("#1B0F0A")!, text: HexColor("#F5E6C8")!, source: .manual),
            typography: ThemeTypography(design: .serif, family: "Cormorant Garamond", titleWeight: .bold, labelTracking: 2.4),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.7, bodyTopRadiusRatio: 0.3, bottomRadiusRatio: 0.5, junctionRatio: 0.26),
            openAnimation: .spring, effects: ThemeEffects(glow: 0.3, borderWidth: 1), background: nil,
            decoration: nil
        ),
        "88394a5a42683eb1": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#9ED8C6")!, secondary: HexColor("#D9C7F2")!, panel: HexColor("#0D1418")!, text: HexColor("#F1F5F4")!, source: .manual),
            typography: ThemeTypography(design: .serif, family: "Cormorant Garamond", titleWeight: .semibold, labelTracking: 2.2),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.8, bodyTopRadiusRatio: 0.55, bottomRadiusRatio: 0.8, junctionRatio: 0.34),
            openAnimation: .smooth, effects: ThemeEffects(glow: 0.3, borderWidth: 0.5), background: nil,
            decoration: nil
        ),
        "25af02383017deac": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#F2C14E")!, secondary: HexColor("#D62828")!, panel: HexColor("#0A1E33")!, text: HexColor("#FFF6E5")!, source: .manual),
            typography: ThemeTypography(design: .system, family: "Bebas Neue", titleWeight: .regular, labelTracking: 3),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.7, bodyTopRadiusRatio: 0.4, bottomRadiusRatio: 0.62, junctionRatio: 0.3),
            openAnimation: .bouncy, effects: ThemeEffects(glow: 0.35, borderWidth: 1), background: nil,
            decoration: .waves
        ),
        "5ca222b9898299b7": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#FF8C1A")!, secondary: HexColor("#3D6FD1")!, panel: HexColor("#140D07")!, text: HexColor("#FFF2E0")!, source: .manual),
            typography: ThemeTypography(design: .system, family: "Big Shoulders Display", titleWeight: .heavy, labelTracking: 2.6),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.7, bodyTopRadiusRatio: 0.26, bottomRadiusRatio: 0.42, junctionRatio: 0.24),
            openAnimation: .spring, effects: ThemeEffects(glow: 0.35, borderWidth: 1), background: nil,
            decoration: nil
        ),
        "1833368969393355": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#E8D3A8")!, secondary: HexColor("#7FA7D9")!, panel: HexColor("#121826")!, text: HexColor("#F6F1E7")!, source: .manual),
            typography: ThemeTypography(design: .serif, family: "Cormorant Garamond", titleWeight: .medium, labelTracking: 2.6),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.8, bodyTopRadiusRatio: 0.5, bottomRadiusRatio: 0.75, junctionRatio: 0.34),
            openAnimation: .fade, effects: ThemeEffects(glow: 0.25, borderWidth: 0.5), background: nil,
            decoration: .ruled
        ),
        "23711f2801d2a95b": Theme(
            id: "", name: "",
            palette: ThemePalette(accent: HexColor("#8CF55B")!, secondary: HexColor("#FF5BC8")!, panel: HexColor("#120A1C")!, text: HexColor("#F9F7FF")!, source: .manual),
            typography: ThemeTypography(design: .rounded, family: "Dela Gothic One", titleWeight: .regular, labelTracking: 1.4),
            shape: ThemeShape(widthRatio: 2.5, bodyRatio: 3.7, bodyTopRadiusRatio: 0.42, bottomRadiusRatio: 0.62, junctionRatio: 0.3),
            openAnimation: .spring, effects: ThemeEffects(glow: 0.5, borderWidth: 0.75), background: nil,
            decoration: .rings
        ),
    ]
}
