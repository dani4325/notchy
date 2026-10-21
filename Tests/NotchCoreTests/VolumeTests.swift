import Foundation
import Testing
@testable import NotchCore

struct MediaKeyTests {
    static func data1(key: Int, down: Bool, isRepeat: Bool = false) -> Int {
        let state = down ? 0xA : 0xB
        return (key << 16) | (state << 8) | (isRepeat ? 1 : 0)
    }

    @Test func decodesVolumeKeys() {
        #expect(MediaKey(data1: Self.data1(key: 0, down: true)) == MediaKey(kind: .volumeUp, isDown: true, isRepeat: false))
        #expect(MediaKey(data1: Self.data1(key: 1, down: false)) == MediaKey(kind: .volumeDown, isDown: false, isRepeat: false))
        #expect(MediaKey(data1: Self.data1(key: 7, down: true, isRepeat: true)) == MediaKey(kind: .mute, isDown: true, isRepeat: true))
    }

    @Test func ignoresOtherSystemKeys() {
        #expect(MediaKey(data1: Self.data1(key: 2, down: true)) == nil)
        #expect(MediaKey(data1: Self.data1(key: 16, down: true)) == nil)
    }
}

struct VolumeStepTests {
    @Test func stepsInSixteenthsAndClamps() {
        #expect(VolumeStep.apply(.volumeUp, to: 0.5) == 0.5625)
        #expect(VolumeStep.apply(.volumeDown, to: 0.03) == 0)
        #expect(VolumeStep.apply(.volumeUp, to: 0.99) == 1)
    }

    @Test func snapsToTheNearestStepLikeMacOS() {
        #expect(VolumeStep.apply(.volumeUp, to: 0.44) == 0.5)
        #expect(VolumeStep.apply(.volumeDown, to: 0.44) == 0.4375)
    }
}

struct VolumeReadingTests {
    @Test func repeatedIdenticalReadingsAreNotNewChanges() {
        let reading = VolumeReading(level: 0.5, isMuted: false)

        #expect(!VolumeReading.isChange(from: reading, to: VolumeReading(level: 0.5, isMuted: false)))
        #expect(VolumeReading.isChange(from: reading, to: VolumeReading(level: 0.5625, isMuted: false)))
        #expect(!VolumeReading.isChange(from: reading, to: VolumeReading(level: 0.5, isMuted: false, output: AudioOutput(name: "Auriculares", kind: .headphones))))
        #expect(VolumeReading.isChange(from: reading, to: VolumeReading(level: 0.5, isMuted: true)))
        #expect(!VolumeReading.isChange(from: nil, to: reading))
    }
}

struct VolumeNudgeTests {
    func reading(_ level: Float, muted: Bool = false) -> VolumeReading {
        VolumeReading(level: level, isMuted: muted)
    }

    @Test func raisingOrLoweringTheLevelBouncesThatWay() {
        #expect(VolumeNudge.Direction.of(from: reading(0.5), to: reading(0.5625), key: nil) == .up)
        #expect(VolumeNudge.Direction.of(from: reading(0.5), to: reading(0.4375), key: nil) == .down)
    }

    @Test func mutingAndUnmutingAreTheirOwnChange() {
        #expect(VolumeNudge.Direction.of(from: reading(0.5), to: reading(0.5, muted: true), key: .mute) == .mute)
        #expect(VolumeNudge.Direction.of(from: reading(0.5, muted: true), to: reading(0.5), key: .mute) == .unmute)
    }

    @Test func pressingAtALimitStillBouncesTowardsTheKey() {
        #expect(VolumeNudge.Direction.of(from: reading(1), to: reading(1), key: .volumeUp) == .up)
        #expect(VolumeNudge.Direction.of(from: reading(0), to: reading(0), key: .volumeDown) == .down)
    }

    @Test func nothingChangedAndNoKeyMeansNoBounce() {
        #expect(VolumeNudge.Direction.of(from: reading(0.5), to: reading(0.5), key: nil) == nil)
        #expect(VolumeNudge.Direction.of(from: nil, to: reading(0.5), key: nil) == nil)
    }

    @Test func eachStepLightsOneMoreSegment() {
        #expect(SegmentedLevel.litSegments(for: 0) == 0)
        #expect(SegmentedLevel.litSegments(for: 1) == SegmentedLevel.count)
        #expect(SegmentedLevel.litSegments(for: VolumeStep.apply(.volumeUp, to: 0.5)) == SegmentedLevel.litSegments(for: 0.5) + 1)
        #expect(SegmentedLevel.litSegments(for: 0.001) == 1)
    }

    @Test func segmentsMoveAwayFromTheVeilSoTheFirstOneIsTheHardestToRead() {
        let panel = HexColor("#000000")!
        let colors = SegmentedLevel.colors(accent: HexColor("#FF6B1A")!, panel: panel, awayFrom: panel.rgb)

        #expect(colors.count == SegmentedLevel.count)
        #expect(OKLCH(colors.last!.rgb).lightness > OKLCH(colors.first!.rgb).lightness)
        #expect(colors.allSatisfy { $0.contrastRatio(with: panel) >= colors[0].contrastRatio(with: panel) - 1e-9 })
    }

    @Test func overABackgroundTheSegmentsKeepTheAccentHue() {
        var theme = Theme.notchyDefault
        theme.palette = ThemePalette(accent: HexColor("#1D29BF")!, secondary: HexColor("#BF6983")!, panel: HexColor("#0E0C1F")!, text: HexColor("#F5F6FF")!, source: .automatic)
        let appearance = ThemeAppearance(theme: theme, background: MediaSource(url: URL(fileURLWithPath: "/fondo.png"), kind: .image))
        let accentHue = OKLCH(HexColor("#1D29BF")!.rgb).hueDegrees

        for color in appearance.levelSegmentColors {
            let difference = abs(OKLCH(color.rgb).hueDegrees - accentHue).truncatingRemainder(dividingBy: 360)
            #expect(min(difference, 360 - difference) < 10)
            #expect(color.contrastRatio(with: theme.palette.panel) >= 3)
        }
    }

    @Test func onALightPanelSegmentsDarkenAwayFromTheWhiteVeil() {
        let panel = HexColor("#F2F2F2")!
        let colors = SegmentedLevel.colors(accent: HexColor("#C21F18")!, panel: panel, awayFrom: RGB(red: 1, green: 1, blue: 1))

        #expect(colors.allSatisfy { $0.contrastRatio(with: panel) >= 3 })
        #expect(OKLCH(colors.last!.rgb).lightness < OKLCH(colors.first!.rgb).lightness)
    }
}
