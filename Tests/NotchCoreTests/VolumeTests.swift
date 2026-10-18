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
        #expect(VolumeReading.isChange(from: reading, to: VolumeReading(level: 0.5, isMuted: true)))
        #expect(!VolumeReading.isChange(from: nil, to: reading))
    }
}
