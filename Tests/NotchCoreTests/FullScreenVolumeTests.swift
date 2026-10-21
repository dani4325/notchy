import CoreGraphics
import Testing
@testable import NotchCore

struct InterceptionSafeguardTests {
    func reading(_ level: Float, muted: Bool = false) -> VolumeReading {
        VolumeReading(level: level, isMuted: muted)
    }

    @Test func raisingAtTheTopIsNotAFailure() {
        #expect(!InterceptionSafeguard.interceptionFailed(before: reading(1), after: reading(1), key: .volumeUp))
    }

    @Test func loweringAtTheBottomIsNotAFailure() {
        #expect(!InterceptionSafeguard.interceptionFailed(before: reading(0), after: reading(0), key: .volumeDown))
    }

    @Test func loweringWhileMutedIsNotAFailure() {
        #expect(!InterceptionSafeguard.interceptionFailed(before: reading(0.5, muted: true), after: reading(0.5, muted: true), key: .volumeDown))
    }

    @Test func aKeyThatChangesNothingInTheMiddleMeansInterceptionFailed() {
        #expect(InterceptionSafeguard.interceptionFailed(before: reading(0.5), after: reading(0.5), key: .volumeUp))
        #expect(InterceptionSafeguard.interceptionFailed(before: reading(0.5), after: reading(0.5), key: .volumeDown))
        #expect(InterceptionSafeguard.interceptionFailed(before: reading(0.5), after: reading(0.5), key: .mute))
    }

    @Test func aKeyThatChangesTheVolumeIsFine() {
        #expect(!InterceptionSafeguard.interceptionFailed(before: reading(0.5), after: reading(0.5625), key: .volumeUp))
        #expect(!InterceptionSafeguard.interceptionFailed(before: reading(0.5), after: reading(0.5, muted: true), key: .mute))
    }
}

struct FullScreenClassifierTests {
    let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
    let notch: CGFloat = 38
    let pid: pid_t = 42

    func window(_ frame: CGRect, owner: pid_t = 42, layer: Int = 0, name: String = "") -> ScreenWindow {
        ScreenWindow(ownerPID: owner, layer: layer, name: name, frame: frame)
    }

    var menuBar: ScreenWindow { window(CGRect(x: 0, y: 0, width: 1710, height: notch), owner: 1, layer: 24, name: "Menubar") }

    @Test func aMaximisedWindowUnderAVisibleMenuBarIsNotFullScreen() {
        let maximised = window(CGRect(x: 0, y: notch, width: 1710, height: 1112 - notch))

        #expect(FullScreenClassifier.classify(windows: [menuBar, maximised], frontmostPID: pid, screen: screen, notchHeight: notch) == .none)
    }

    @Test func aFullScreenAppBelowTheNotchLeavesTheBlackStrip() {
        let fullScreen = window(CGRect(x: 0, y: notch, width: 1710, height: 1112 - notch))

        #expect(FullScreenClassifier.classify(windows: [fullScreen], frontmostPID: pid, screen: screen, notchHeight: notch) == .besideNotch)
    }

    @Test func aFullScreenAppThatUsesTheNotchAreaCoversIt() {
        let fullScreen = window(screen)

        #expect(FullScreenClassifier.classify(windows: [fullScreen], frontmostPID: pid, screen: screen, notchHeight: notch) == .coversNotch)
    }

    @Test func otherAppsWindowsDoNotCount() {
        let someoneElse = window(screen, owner: 7)

        #expect(FullScreenClassifier.classify(windows: [someoneElse], frontmostPID: pid, screen: screen, notchHeight: notch) == .none)
    }

    @Test func aSmallWindowIsNeverFullScreen() {
        let small = window(CGRect(x: 100, y: 100, width: 800, height: 600))

        #expect(FullScreenClassifier.classify(windows: [small], frontmostPID: pid, screen: screen, notchHeight: notch) == .none)
    }
}

struct CompactOnlyPresentationTests {
    @Test func inFullScreenTheHUDGoesStraightToTheWingsAndThenHides() {
        var presentation = VolumePresentation(allowsCompact: true, compactOnly: true)

        _ = presentation.press()
        #expect(presentation.phase == .compact)
        #expect(presentation.tick() == nil)
        #expect(presentation.phase == .hidden)
    }
}
