import Testing
@testable import NotchCore

struct PaletteContrastTests {
    func palette(accent: String = "#FF6B1A", secondary: String = "#FFB347", panel: String = "#000000", text: String = "#FFFFFF", source: PaletteSource = .manual) -> ThemePalette {
        ThemePalette(accent: HexColor(accent)!, secondary: HexColor(secondary)!, panel: HexColor(panel)!, text: HexColor(text)!, source: source)
    }

    @Test func aPaletteThatReachesEveryMinimumHasNoIssues() {
        #expect(PaletteContrastCheck.issues(in: palette()).isEmpty)
    }

    @Test func anAccentThatOnlyWorksForGraphicsIsReportedAsTextOnly() throws {
        let issues = PaletteContrastCheck.issues(in: palette(accent: "#1E3AFF"))

        let accent = try #require(issues.first { $0.role == .accent })
        #expect(accent.failsText)
        #expect(!accent.failsGraphic)
        #expect(abs(accent.ratio - 3.10) < 0.01)
        #expect(accent.corrected.contrastRatio(with: HexColor("#000000")!) >= 4.5)
    }

    @Test func aColorThatFailsBothUsesSaysSo() throws {
        let issues = PaletteContrastCheck.issues(in: palette(secondary: "#3B2A1A"))

        let secondary = try #require(issues.first { $0.role == .secondary })
        #expect(secondary.failsText)
        #expect(secondary.failsGraphic)
    }

    @Test func textIsCheckedAtTheSecondaryOpacityAndItsCorrectionReachesTheMinimumThere() throws {
        let panel = HexColor("#F2F2F2")!
        let issues = PaletteContrastCheck.issues(in: palette(panel: "#F2F2F2", text: "#777777"))

        let text = try #require(issues.first { $0.role == .text })
        let mixed = PaletteContrastCheck.mixed(text.corrected, over: panel, opacity: ThemeAppearance.secondaryTextOpacity)
        #expect(mixed.contrastRatio(with: panel) >= 4.5)
    }

    @Test func automaticPalettesAreCorrectedSilentlyAndNeverWarn() {
        #expect(PaletteContrastCheck.issues(in: palette(accent: "#1E3AFF", source: .automatic)).isEmpty)
    }
}
