import Testing
@testable import NotchCore

struct VolumePresentationTests {
    @Test func aPressShowsTheFullViewForOneSecond() {
        var presentation = VolumePresentation(allowsCompact: true)

        let wait = presentation.press()

        #expect(presentation.phase == .expanded)
        #expect(wait == VolumePresentation.expandedHold)
    }

    @Test func afterOneSecondItShrinksToTheWingsAndThenDisappears() {
        var presentation = VolumePresentation(allowsCompact: true)
        _ = presentation.press()

        let compactWait = presentation.tick()
        #expect(presentation.phase == .compact)
        #expect(compactWait == VolumePresentation.compactHold)

        let last = presentation.tick()
        #expect(presentation.phase == .hidden)
        #expect(last == nil)
    }

    @Test func pressingWhileCompactStaysCompactAndRestartsItsTime() {
        var presentation = VolumePresentation(allowsCompact: true)
        _ = presentation.press()
        _ = presentation.tick()

        let wait = presentation.press()

        #expect(presentation.phase == .compact)
        #expect(wait == VolumePresentation.compactHold)
    }

    @Test func pressingWhileExpandedKeepsTheFullViewAndRestartsItsSecond() {
        var presentation = VolumePresentation(allowsCompact: true)
        _ = presentation.press()

        let wait = presentation.press()

        #expect(presentation.phase == .expanded)
        #expect(wait == VolumePresentation.expandedHold)
    }

    @Test func withoutRoomForWingsItHidesStraightAfterTheFullView() {
        var presentation = VolumePresentation(allowsCompact: false)
        _ = presentation.press()

        let next = presentation.tick()

        #expect(presentation.phase == .hidden)
        #expect(next == nil)
    }

    @Test func aTickWhileHiddenDoesNothing() {
        var presentation = VolumePresentation(allowsCompact: true)

        #expect(presentation.tick() == nil)
        #expect(presentation.phase == .hidden)
    }

    @Test func pressesAtTheLimitsAreDetected() {
        #expect(VolumeLimit.reached(before: 1, after: 1, kind: .volumeUp) == .top)
        #expect(VolumeLimit.reached(before: 0, after: 0, kind: .volumeDown) == .bottom)
        #expect(VolumeLimit.reached(before: 0.5, after: 0.5625, kind: .volumeUp) == nil)
        #expect(VolumeLimit.reached(before: 1, after: 1, kind: .volumeDown) == nil)
        #expect(VolumeLimit.reached(before: 0.3, after: 0.3, kind: .mute) == nil)
    }
}
