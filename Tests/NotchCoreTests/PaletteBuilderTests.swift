import Testing
@testable import NotchCore

struct PaletteBuilderTests {
    let hexRounding = 0.5 / 255
    let red = RGB(red: 0.85, green: 0.1, blue: 0.1)
    let teal = RGB(red: 0.1, green: 0.7, blue: 0.65)
    let gray = RGB(red: 0.5, green: 0.5, blue: 0.5)
    let navy = RGB(red: 0.05, green: 0.06, blue: 0.2)

    @Test func accentIsTheMostVividWeightedCluster() {
        let palette = PaletteBuilder.palette(from: [
            .init(color: gray, weight: 0.6), .init(color: red, weight: 0.3), .init(color: navy, weight: 0.1),
        ])

        #expect(palette.accent.rgb.hue < 0.03 || palette.accent.rgb.hue > 0.97)
        #expect(palette.source == .automatic)
    }

    @Test func secondaryHasADistinctHueWhenAvailable() {
        let palette = PaletteBuilder.palette(from: [
            .init(color: red, weight: 0.4), .init(color: teal, weight: 0.35), .init(color: gray, weight: 0.25),
        ])

        let distance = PaletteBuilder.hueDistance(palette.accent.rgb.hue, palette.secondary.rgb.hue)
        #expect(distance > PaletteBuilder.minimumHueDistance)
    }

    @Test func accentIsBrightEnoughOnADarkPanel() {
        let darkRed = RGB(red: 0.25, green: 0.02, blue: 0.02)

        let palette = PaletteBuilder.palette(from: [.init(color: darkRed, weight: 1)])

        #expect(palette.accent.rgb.brightness >= PaletteBuilder.minimumAccentBrightness - hexRounding)
    }

    @Test func panelStaysDarkAndTextStaysLight() {
        let palette = PaletteBuilder.palette(from: [
            .init(color: RGB(red: 0.95, green: 0.9, blue: 0.8), weight: 0.7), .init(color: red, weight: 0.3),
        ])

        #expect(palette.panel.rgb.brightness <= PaletteBuilder.maximumPanelBrightness + hexRounding)
        #expect(palette.text.rgb.brightness >= 0.9)
    }

    @Test func grayscaleInputStillProducesUsablePalette() {
        let palette = PaletteBuilder.palette(from: [.init(color: gray, weight: 1)])

        #expect(palette.accent.rgb.brightness >= PaletteBuilder.minimumAccentBrightness - hexRounding)
    }

    @Test func emptyInputFallsBackToDefaultPalette() {
        #expect(PaletteBuilder.palette(from: []) == Theme.notchyDefault.palette)
    }
}
