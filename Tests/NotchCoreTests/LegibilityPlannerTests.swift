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
        let sample = try #require(BackgroundSample.measuring(solid(255), crop: .standard, size: CGSize(width: 8, height: 8)))
        let text = zone([.init(color: white, opacity: 1, use: .text)])

        let strength = LegibilityPlanner.strength(for: text, over: sample, scrim: black, atLeast: 0)

        #expect(LegibilityPlanner.worstRatio(for: text, over: sample, scrim: black, strength: strength) >= 4.5)
        #expect(LegibilityPlanner.worstRatio(for: text, over: sample, scrim: black, strength: strength - 0.02) < 4.5)
    }

    @Test func darkImagesKeepTheUserMinimum() throws {
        let sample = try #require(BackgroundSample.measuring(solid(0), crop: .standard, size: CGSize(width: 8, height: 8)))
        let text = zone([.init(color: white, opacity: 1, use: .text)])

        #expect(LegibilityPlanner.strength(for: text, over: sample, scrim: black, atLeast: 0.2) == 0.2)
    }

    @Test func translucentTextNeedsMoreDarkeningThanOpaqueText() throws {
        let sample = try #require(BackgroundSample.measuring(solid(255), crop: .standard, size: CGSize(width: 8, height: 8)))
        let opaque = zone([.init(color: white, opacity: 1, use: .text)])
        let translucent = zone([.init(color: white, opacity: 0.72, use: .text)])

        #expect(LegibilityPlanner.strength(for: translucent, over: sample, scrim: black, atLeast: 0)
            > LegibilityPlanner.strength(for: opaque, over: sample, scrim: black, atLeast: 0))
    }

    @Test func graphicsOnlyNeedThreeToOne() throws {
        let sample = try #require(BackgroundSample.measuring(solid(255), crop: .standard, size: CGSize(width: 8, height: 8)))
        let text = zone([.init(color: white, opacity: 1, use: .text)])
        let graphic = zone([.init(color: white, opacity: 1, use: .graphic)])

        let graphicStrength = LegibilityPlanner.strength(for: graphic, over: sample, scrim: black, atLeast: 0)

        #expect(graphicStrength < LegibilityPlanner.strength(for: text, over: sample, scrim: black, atLeast: 0))
        #expect(LegibilityPlanner.worstRatio(for: graphic, over: sample, scrim: black, strength: graphicStrength) >= 3)
    }

    @Test func darkTextOverALightPanelHandlesDarkImages() throws {
        let sample = try #require(BackgroundSample.measuring(solid(0), crop: .standard, size: CGSize(width: 8, height: 8)))
        let text = zone([.init(color: HexColor("#111111")!.rgb, opacity: 1, use: .text)])

        let strength = LegibilityPlanner.strength(for: text, over: sample, scrim: lightPanel, atLeast: 0)

        #expect(strength > 0)
        #expect(LegibilityPlanner.worstRatio(for: text, over: sample, scrim: lightPanel, strength: strength) >= 4.5)
    }

    @Test func onlyThePixelsBehindTheZoneCount() throws {
        let halves = image(width: 16, height: 4) { x, _ in x < 8 ? (255, 255, 255) : (0, 0, 0) }
        let sample = try #require(BackgroundSample.measuring(halves, crop: .standard, size: CGSize(width: 16, height: 4)))
        let rightText = zone([.init(color: white, opacity: 1, use: .text)], horizontal: 0.5...1)

        #expect(LegibilityPlanner.strength(for: rightText, over: sample, scrim: black, atLeast: 0) == 0)
    }

    @Test func theCropDecidesWhichPartOfTheImageIsMeasured() throws {
        let halves = image(width: 32, height: 8) { x, _ in x < 16 ? (255, 255, 255) : (0, 0, 0) }
        let darkHalf = MediaCrop(zoom: 2, focusX: 0.75, focusY: 0.5)
        let sample = try #require(BackgroundSample.measuring(halves, crop: darkHalf, size: CGSize(width: 16, height: 8)))
        let text = zone([.init(color: white, opacity: 1, use: .text)])

        #expect(LegibilityPlanner.strength(for: text, over: sample, scrim: black, atLeast: 0) == 0)
    }

    @Test func animationFramesAreCombinedKeepingTheWorstPixels() throws {
        let size = CGSize(width: 8, height: 8)
        let dark = try #require(BackgroundSample.measuring(solid(0), crop: .standard, size: size))
        let bright = try #require(BackgroundSample.measuring(solid(255), crop: .standard, size: size))
        let text = zone([.init(color: white, opacity: 1, use: .text)])

        let combined = dark.merged(with: bright)

        #expect(LegibilityPlanner.strength(for: text, over: combined, scrim: black, atLeast: 0)
            == LegibilityPlanner.strength(for: text, over: bright, scrim: black, atLeast: 0))
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
        let sample = try #require(BackgroundSample.measuring(solid(255), crop: .standard, size: CGSize(width: 8, height: 8)))
        let panel = HexColor("#120A1E")!.rgb
        let text = zone([.init(color: white, opacity: 1, use: .text)])

        let strength = LegibilityPlanner.strength(for: text, over: sample, scrim: panel, atLeast: 0)
        let background = renderedLuminance(scrim: panel, over: white, strength: strength, gamma: gamma)

        #expect((1 + 0.05) / (background + 0.05) >= 4.5, "gamma \(gamma): \((1 + 0.05) / (background + 0.05))")
    }

    @Test func stopsKeepEveryZoneAtLeastAtItsStrength() {
        let boundaries = [0.3, 0.8]
        let strengths = [0.2, 0.9, 0.5]

        let stops = LegibilityPlanner.stops(boundaries: boundaries, strengths: strengths, ramp: 0.05)

        for position in stride(from: 0.0, through: 1.0, by: 0.01) {
            let zone = boundaries.firstIndex { position < $0 } ?? strengths.count - 1
            #expect(LegibilityPlanner.value(of: stops, at: position) >= strengths[zone] - 1e-9, "en \(position)")
        }
    }
}
