import Testing
@testable import NotchCore

extension ContrastCorrection.Use: CustomTestStringConvertible {
    public var testDescription: String { self == .text ? "texto 4,5:1" : "gráfico 3:1" }
}

struct ContrastCorrectionTests {
    struct Case: CustomTestStringConvertible, Sendable {
        let color: String
        let panel: String
        let textCorrectionLeavesSRGBWithSameChroma: Bool

        var testDescription: String { "\(color) sobre \(panel)" }
    }

    static let cases: [Case] = [
        Case(color: "#D7261E", panel: "#F2F2F2", textCorrectionLeavesSRGBWithSameChroma: false),
        Case(color: "#1E3AFF", panel: "#000000", textCorrectionLeavesSRGBWithSameChroma: true),
        Case(color: "#7A00FF", panel: "#000000", textCorrectionLeavesSRGBWithSameChroma: true),
        Case(color: "#FFE600", panel: "#F2F2F2", textCorrectionLeavesSRGBWithSameChroma: true),
        Case(color: "#00C2FF", panel: "#F2F2F2", textCorrectionLeavesSRGBWithSameChroma: true),
        Case(color: "#3B2A1A", panel: "#000000", textCorrectionLeavesSRGBWithSameChroma: false),
    ]

    static let uses = ContrastCorrection.Use.allCases
    static let maximumHueShift = 3.0

    func hueDistance(_ a: Double, _ b: Double) -> Double {
        let difference = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(difference, 360 - difference)
    }

    @Test(arguments: cases, uses)
    func correctedColorReachesTheMinimumAfterRoundingToEightBits(_ testCase: Case, use: ContrastCorrection.Use) throws {
        let color = try #require(HexColor(testCase.color))
        let panel = try #require(HexColor(testCase.panel))

        let corrected = ContrastCorrection.corrected(color, against: panel, for: use)

        #expect(corrected.contrastRatio(with: panel) >= use.minimumRatio)
    }

    @Test(arguments: cases, uses)
    func correctedColorKeepsTheOriginalHue(_ testCase: Case, use: ContrastCorrection.Use) throws {
        let color = try #require(HexColor(testCase.color))
        let panel = try #require(HexColor(testCase.panel))

        let corrected = ContrastCorrection.corrected(color, against: panel, for: use)

        let shift = hueDistance(OKLCH(corrected.rgb).hueDegrees, OKLCH(color.rgb).hueDegrees)
        #expect(shift <= Self.maximumHueShift, "el tono se ha desviado \(shift)°")
    }

    @Test(arguments: cases, uses)
    func correctionFitsInSRGBAndOnlyLowersChromaWhenItMust(_ testCase: Case, use: ContrastCorrection.Use) throws {
        let color = try #require(HexColor(testCase.color))
        let panel = try #require(HexColor(testCase.panel))
        let original = OKLCH(color.rgb)

        let target = ContrastCorrection.correctedOKLCH(color, against: panel, for: use)
        let sameChroma = OKLCH(lightness: target.lightness, chroma: original.chroma, hue: target.hue)

        #expect(target.isInSRGB)
        if sameChroma.isInSRGB {
            #expect(abs(target.chroma - original.chroma) < 0.0001)
        } else {
            #expect(target.chroma < original.chroma)
        }
        if use == .text {
            #expect(sameChroma.isInSRGB == !testCase.textCorrectionLeavesSRGBWithSameChroma)
        }
    }

    @Test func graphicUseAcceptsColorsThatOnlyFailAsText() throws {
        let blue = try #require(HexColor("#1E3AFF"))
        let black = try #require(HexColor("#000000"))

        #expect(ContrastCorrection.corrected(blue, against: black, for: .graphic) == blue)
        #expect(ContrastCorrection.corrected(blue, against: black, for: .text) != blue)
    }

    @Test func colorsThatAlreadyReachTheMinimumAreLeftUntouched() throws {
        let accent = try #require(HexColor("#FF6B1A"))
        let black = try #require(HexColor("#000000"))

        #expect(ContrastCorrection.corrected(accent, against: black, for: .text) == accent)
        #expect(ContrastCorrection.corrected(accent, against: black, for: .graphic) == accent)
    }

    @Test func darkPanelsLightenTheColorAndLightPanelsDarkenIt() throws {
        let blue = try #require(HexColor("#1E3AFF"))
        let yellow = try #require(HexColor("#FFE600"))

        #expect(OKLCH(ContrastCorrection.corrected(blue, against: HexColor("#000000")!, for: .text).rgb).lightness > OKLCH(blue.rgb).lightness)
        #expect(OKLCH(ContrastCorrection.corrected(yellow, against: HexColor("#F2F2F2")!, for: .graphic).rgb).lightness < OKLCH(yellow.rgb).lightness)
    }

    @Test func contrastRatioMatchesTheWCAGReferenceValues() throws {
        let white = try #require(HexColor("#FFFFFF"))
        let black = try #require(HexColor("#000000"))
        let red = try #require(HexColor("#D7261E"))
        let panel = try #require(HexColor("#F2F2F2"))

        #expect(abs(white.contrastRatio(with: black) - 21) < 0.001)
        #expect(abs(red.contrastRatio(with: panel) - 4.48) < 0.01)
    }

    @Test func gamutMappingKeepsLightnessAndHueAndOnlyLowersChroma() {
        let outside = OKLCH(lightness: 0.55, chroma: 0.35, hue: OKLCH(HexColor("#1E3AFF")!.rgb).hue)

        let mapped = outside.mappedIntoSRGB()

        #expect(!outside.isInSRGB)
        #expect(mapped.isInSRGB)
        #expect(abs(mapped.lightness - outside.lightness) < 0.0001)
        #expect(hueDistance(mapped.hueDegrees, outside.hueDegrees) < 0.0001)
        #expect(mapped.chroma < outside.chroma)
    }
}
