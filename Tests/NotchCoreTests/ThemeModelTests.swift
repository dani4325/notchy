import Foundation
import Testing
@testable import NotchCore

struct ThemeModelTests {
    @Test func hexColorParsesAndNormalizes() throws {
        let color = try #require(HexColor("ff6b1a"))

        #expect(color.hex == "#FF6B1A")
        #expect(abs(color.red - 1) < 0.001)
        #expect(abs(color.green - 0.42) < 0.01)
        #expect(color.alpha == 1)
    }

    @Test func hexColorRejectsGarbage() {
        #expect(HexColor("zzz") == nil)
        #expect(HexColor("#12345") == nil)
    }

    @Test func themeRoundTripsThroughJSON() throws {
        let theme = Theme.notchyDefault

        let data = try JSONEncoder().encode(theme)
        let decoded = try JSONDecoder().decode(Theme.self, from: data)

        #expect(decoded == theme)
    }

    @Test func missingSectionsFallBackToDefaults() throws {
        let json = #"{"id":"abc","name":"Mínimo"}"#

        let theme = try JSONDecoder().decode(Theme.self, from: Data(json.utf8))

        #expect(theme.name == "Mínimo")
        #expect(theme.palette == Theme.notchyDefault.palette)
        #expect(theme.shape == ThemeShape.standard)
        #expect(theme.background == nil)
    }

    @Test func sanitizeClampsOutOfRangeValues() {
        let wild = ThemeShape(widthRatio: 50, bodyRatio: 0.1, bodyTopRadiusRatio: -3, bottomRadiusRatio: 400, junctionRatio: 99)

        let safe = wild.sanitized()

        #expect(safe.widthRatio == ThemeShape.widthRange.upperBound)
        #expect(safe.bodyRatio == ThemeShape.bodyRange.lowerBound)
        #expect(safe.bodyTopRadiusRatio == 0)
        #expect(safe.bottomRadiusRatio == ThemeShape.radiusRange.upperBound)
    }

    @Test func mediaFileNamesMustStayInsideTheThemeFolder() {
        #expect(ThemeMedia.isSafeFileName("bg-1.png"))
        #expect(!ThemeMedia.isSafeFileName("../evil.png"))
        #expect(!ThemeMedia.isSafeFileName("sub/dir.png"))
        #expect(!ThemeMedia.isSafeFileName(""))
        #expect(!ThemeMedia.isSafeFileName(".hidden"))
    }
}
