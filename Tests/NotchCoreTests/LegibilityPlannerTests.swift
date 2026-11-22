import CoreGraphics
import Foundation
import Testing
@testable import NotchCore

struct LegibilityPlannerTests {
    let white = RGB(red: 1, green: 1, blue: 1)
    let black = RGB(red: 0, green: 0, blue: 0)
    let lightPanel = HexColor("#F2F2F2")!.rgb

    func image(width: Int, height: Int, pixel: (Int, Int) -> (UInt8, UInt8, UInt8)) -> CGImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let (r, g, b) = pixel(x, y)
                let index = (y * width + x) * 4
                bytes[index] = r; bytes[index + 1] = g; bytes[index + 2] = b
            }
        }
        let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    func solid(_ value: UInt8) -> CGImage { image(width: 8, height: 8) { _, _ in (value, value, value) } }

    func zone(_ foregrounds: [ScrimZone.Foreground], horizontal: ClosedRange<Double> = 0...1) -> ScrimZone {
        ScrimZone(horizontal: horizontal, vertical: 0...1, foregrounds: foregrounds)
    }

    @Test func whiteTextOverAWhiteImageGetsJustEnoughDarkening() throws {
        let sample = try #require(BackgroundSample.measuring(solid(255))).framed(crop: .standard, targetAspect: 1)
        let text = zone([.init(color: white, opacity: 1, use: .text)])

        let strength = LegibilityPlanner.strength(for: text, over: sample, scrim: black, atLeast: 0)

        #expect(LegibilityPlanner.worstRatio(for: text, over: sample, scrim: black, strength: strength) >= 4.5)
        #expect(LegibilityPlanner.worstRatio(for: text, over: sample, scrim: black, strength: strength - 0.02) < 4.5)
    }

    @Test func darkImagesKeepTheUserMinimum() throws {
        let sample = try #require(BackgroundSample.measuring(solid(0))).framed(crop: .standard, targetAspect: 1)
        let text = zone([.init(color: white, opacity: 1, use: .text)])

        #expect(LegibilityPlanner.strength(for: text, over: sample, scrim: black, atLeast: 0.2) == 0.2)
    }

    @Test func translucentTextNeedsMoreDarkeningThanOpaqueText() throws {
        let sample = try #require(BackgroundSample.measuring(solid(255))).framed(crop: .standard, targetAspect: 1)
        let opaque = zone([.init(color: white, opacity: 1, use: .text)])
        let translucent = zone([.init(color: white, opacity: 0.72, use: .text)])

        #expect(LegibilityPlanner.strength(for: translucent, over: sample, scrim: black, atLeast: 0)
            > LegibilityPlanner.strength(for: opaque, over: sample, scrim: black, atLeast: 0))
    }

    @Test func graphicsOnlyNeedThreeToOne() throws {
        let sample = try #require(BackgroundSample.measuring(solid(255))).framed(crop: .standard, targetAspect: 1)
        let text = zone([.init(color: white, opacity: 1, use: .text)])
        let graphic = zone([.init(color: white, opacity: 1, use: .graphic)])

        let graphicStrength = LegibilityPlanner.strength(for: graphic, over: sample, scrim: black, atLeast: 0)

        #expect(graphicStrength < LegibilityPlanner.strength(for: text, over: sample, scrim: black, atLeast: 0))
        #expect(LegibilityPlanner.worstRatio(for: graphic, over: sample, scrim: black, strength: graphicStrength) >= 3)
    }

    @Test func darkTextOverALightPanelHandlesDarkImages() throws {
        let sample = try #require(BackgroundSample.measuring(solid(0))).framed(crop: .standard, targetAspect: 1)
        let text = zone([.init(color: HexColor("#111111")!.rgb, opacity: 1, use: .text)])

        let strength = LegibilityPlanner.strength(for: text, over: sample, scrim: lightPanel, atLeast: 0)

        #expect(strength > 0)
        #expect(LegibilityPlanner.worstRatio(for: text, over: sample, scrim: lightPanel, strength: strength) >= 4.5)
    }

    @Test func onlyThePixelsBehindTheZoneCount() throws {
        let halves = image(width: 16, height: 4) { x, _ in x < 8 ? (255, 255, 255) : (0, 0, 0) }
        let sample = try #require(BackgroundSample.measuring(halves)).framed(crop: .standard, targetAspect: 4)
        let rightText = zone([.init(color: white, opacity: 1, use: .text)], horizontal: 0.5...1)

        #expect(LegibilityPlanner.strength(for: rightText, over: sample, scrim: black, atLeast: 0) == 0)
    }

    @Test func theCropDecidesWhichPartOfTheImageIsMeasured() throws {
        let halves = image(width: 32, height: 8) { x, _ in x < 16 ? (255, 255, 255) : (0, 0, 0) }
        let darkHalf = MediaCrop(zoom: 2, focusX: 0.75, focusY: 0.5)
        let sample = try #require(BackgroundSample.measuring(halves)).framed(crop: darkHalf, targetAspect: 2)
        let text = zone([.init(color: white, opacity: 1, use: .text)])

        #expect(LegibilityPlanner.strength(for: text, over: sample, scrim: black, atLeast: 0) == 0)
    }

    @Test func animationFramesAreCombinedKeepingTheWorstPixels() throws {
        let dark = try #require(BackgroundSample.measuring(solid(0)))
        let bright = try #require(BackgroundSample.measuring(solid(255)))
        let text = zone([.init(color: white, opacity: 1, use: .text)])

        let combined = dark.merged(with: bright).framed(crop: .standard, targetAspect: 1)

        #expect(LegibilityPlanner.strength(for: text, over: combined, scrim: black, atLeast: 0)
            == LegibilityPlanner.strength(for: text, over: bright.framed(crop: .standard, targetAspect: 1), scrim: black, atLeast: 0))
    }

    func renderedLuminance(scrim: RGB, over background: RGB, strength: Double, gamma: Double) -> Double {
        let mix = { (top: Double, bottom: Double) in
            pow(strength * pow(top, 1 / gamma) + (1 - strength) * pow(bottom, 1 / gamma), gamma)
        }
        let linear = RGB(
            red: mix(OKLCH.linear(scrim.red), OKLCH.linear(background.red)),
            green: mix(OKLCH.linear(scrim.green), OKLCH.linear(background.green)),
            blue: mix(OKLCH.linear(scrim.blue), OKLCH.linear(background.blue))
        )
        return 0.2126 * linear.red + 0.7152 * linear.green + 0.0722 * linear.blue
    }

    @Test(arguments: [1.0, 1.8, 2.2, 2.4])
    func theStrengthHoldsWhateverGammaTheSystemBlendsWith(gamma: Double) throws {
        let sample = try #require(BackgroundSample.measuring(solid(255))).framed(crop: .standard, targetAspect: 1)
        let panel = HexColor("#120A1E")!.rgb
        let text = zone([.init(color: white, opacity: 1, use: .text)])

        let strength = LegibilityPlanner.strength(for: text, over: sample, scrim: panel, atLeast: 0)
        let background = renderedLuminance(scrim: panel, over: white, strength: strength, gamma: gamma)

        #expect((1 + 0.05) / (background + 0.05) >= 4.5, "gamma \(gamma): \((1 + 0.05) / (background + 0.05))")
    }

    @Test func aMeasurementSurvivesBeingSavedAndLoaded() throws {
        let halves = image(width: 16, height: 4) { x, _ in x < 8 ? (255, 255, 255) : (0, 0, 0) }
        let measurement = BackgroundMeasurement(sample: try #require(BackgroundSample.measuring(halves)), framesChecked: 1, coversEveryFrame: true)

        let restored = try JSONDecoder().decode(BackgroundMeasurement.self, from: JSONEncoder().encode(measurement))

        #expect(restored == measurement)
    }

    @Test func zoomingIntoTheDarkHalfNeedsNoNewMeasurement() throws {
        let halves = image(width: 64, height: 16) { x, _ in x < 32 ? (255, 255, 255) : (0, 0, 0) }
        let sample = try #require(BackgroundSample.measuring(halves))
        let text = zone([.init(color: white, opacity: 1, use: .text)])

        let wide = LegibilityPlanner.strength(for: text, over: sample.framed(crop: .standard, targetAspect: 4), scrim: black, atLeast: 0)
        let zoomed = LegibilityPlanner.strength(for: text, over: sample.framed(crop: MediaCrop(zoom: 3, focusX: 0.85, focusY: 0.5), targetAspect: 4), scrim: black, atLeast: 0)

        #expect(wide > 0)
        #expect(zoomed == 0)
    }
}

@MainActor
struct ScrimZoneRequirementTests {
    let size = CGSize(width: 500, height: 130)
    let title = LegibilityMark(needs: .text, rect: CGRect(x: 20, y: 30, width: 100, height: 16))
    let controls = LegibilityMark(needs: .graphics, rect: CGRect(x: 420, y: 50, width: 20, height: 18))

    func foregrounds(_ theme: Theme, _ needs: LegibilityNeeds) -> [ScrimZone.Foreground] {
        ScrimPlan.foregrounds(for: needs, appearance: ThemeAppearance(theme: theme, background: nil))
    }

    @Test func theAccentOnlyNeedsTextContrastWhereItIsDrawnAsText() {
        #expect(!foregrounds(.notchyDefault, .text).contains { $0.color == Theme.notchyDefault.palette.accent.rgb })
        #expect(foregrounds(.fosforo, .text).contains { $0.use == .text && $0.color == Theme.fosforo.palette.accent.rgb })
    }

    @Test func theSecondaryColorIsNotRequiredBecauseThePanelNeverDrawsIt() {
        let secondary = Theme.notchyDefault.palette.secondary.rgb

        #expect(!foregrounds(.notchyDefault, [.text, .graphics]).contains { $0.color == secondary })
    }

    @Test func eachMarkGetsOnlyTheDarkeningItsOwnPixelsNeedUpToTheCap() throws {
        let halves = LegibilityPlannerTests().image(width: 20, height: 4) { x, _ in x < 10 ? (0, 0, 0) : (255, 255, 255) }
        let measurement = BackgroundMeasurement(sample: try #require(BackgroundSample.measuring(halves)), framesChecked: 1, coversEveryFrame: true)
        let appearance = ThemeAppearance(theme: .notchyDefault, background: MediaSource(url: URL(fileURLWithPath: "/fondo.png"), kind: .image), measurement: measurement)

        let spots = VeilCache.spots(for: measurement, crop: .standard, size: size, appearance: appearance, marks: [title, controls], minimum: 0)

        #expect(spots[0].strength == 0)
        #expect(spots[1].strength == LegibilityScrim.maximumVeil)
    }

    @Test func aDarkAutomaticAccentNoLongerHidesABrightBackground() throws {
        var theme = Theme.notchyDefault
        theme.palette = ThemePalette(accent: HexColor("#1D29BF")!, secondary: HexColor("#BF6983")!, panel: HexColor("#0E0C1F")!, text: HexColor("#F5F6FF")!, source: .automatic)
        let bright = try #require(BackgroundSample.measuring(LegibilityPlannerTests().solid(200)))
        let measurement = BackgroundMeasurement(sample: bright, framesChecked: 1, coversEveryFrame: true)
        let appearance = ThemeAppearance(theme: theme, background: MediaSource(url: URL(fileURLWithPath: "/fondo.png"), kind: .image), measurement: measurement)

        let spots = VeilCache.spots(for: measurement, crop: .standard, size: size, appearance: appearance, marks: [controls], minimum: 0)

        #expect(spots.allSatisfy { $0.strength < 0.95 }, "\(spots)")
    }
}

struct FramingAdviceTests {
    func measurement(_ pixel: (Int, Int) -> (UInt8, UInt8, UInt8)) throws -> BackgroundMeasurement {
        let image = LegibilityPlannerTests().image(width: 40, height: 10, pixel: pixel)
        return BackgroundMeasurement(sample: try #require(BackgroundSample.measuring(image)), framesChecked: 1, coversEveryFrame: true)
    }

    @Test func aWhiteBackgroundBehindTheTextAsksToMoveTheFraming() throws {
        let white = try measurement { _, _ in (255, 255, 255) }

        #expect(FramingAdvice.needsDarkerArea(measurement: white, crop: .standard, theme: .notchyDefault))
    }

    @Test func aDarkBackgroundNeedsNoAdvice() throws {
        let dark = try measurement { _, _ in (40, 40, 40) }

        #expect(!FramingAdvice.needsDarkerArea(measurement: dark, crop: .standard, theme: .notchyDefault))
    }

    @Test func movingTheFramingToADarkAreaRemovesTheAdvice() throws {
        let halves = try measurement { x, _ in x < 20 ? (20, 20, 20) : (255, 255, 255) }

        #expect(FramingAdvice.needsDarkerArea(measurement: halves, crop: MediaCrop(zoom: 2.5, focusX: 0.8, focusY: 0.5), theme: .notchyDefault))
        #expect(!FramingAdvice.needsDarkerArea(measurement: halves, crop: MediaCrop(zoom: 2.5, focusX: 0.2, focusY: 0.5), theme: .notchyDefault))
    }
}
