import Foundation
import Testing
@testable import NotchCore

struct IconChipTests {
    func encodedMix(_ top: RGB, over bottom: RGB, alpha: Double) -> RGB {
        RGB(red: alpha * top.red + (1 - alpha) * bottom.red,
            green: alpha * top.green + (1 - alpha) * bottom.green,
            blue: alpha * top.blue + (1 - alpha) * bottom.blue)
    }

    func linearMix(_ top: RGB, over bottom: RGB, alpha: Double) -> RGB {
        let mix = { (a: Double, b: Double) in OKLCH.encode(alpha * OKLCH.linear(a) + (1 - alpha) * OKLCH.linear(b)) }
        return RGB(red: mix(top.red, bottom.red), green: mix(top.green, bottom.green), blue: mix(top.blue, bottom.blue))
    }

    @Test(arguments: [Theme.notchyDefault, .cartel, .fosforo])
    func iconsReachThreeToOneOnTheChipWhateverTheBackground(_ theme: Theme) {
        let appearance = ThemeAppearance(theme: theme, background: MediaSource(url: URL(fileURLWithPath: "/fondo.png"), kind: .image))
        let worst = appearance.hasLightText ? RGB(red: 1, green: 1, blue: 1) : RGB(red: 0, green: 0, blue: 0)
        let icon = HexColor(rgb: theme.palette.text.rgb)

        for chip in [encodedMix(appearance.scrimRGB, over: worst, alpha: IconChip.opacity), linearMix(appearance.scrimRGB, over: worst, alpha: IconChip.opacity)] {
            #expect(icon.contrastRatio(with: HexColor(rgb: chip)) >= 3, "\(theme.name)")
        }
    }
}
