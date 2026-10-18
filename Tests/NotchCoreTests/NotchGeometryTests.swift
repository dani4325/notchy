import CoreGraphics
import Testing
@testable import NotchCore

struct NotchGeometryTests {
    let notchedScreen = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1710, height: 1112),
        visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1074),
        safeAreaTop: 37.5,
        auxiliaryLeftWidth: 751,
        auxiliaryRightWidth: 751
    )

    let externalScreen = ScreenMetrics(
        frame: CGRect(x: 1710, y: 0, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 1710, y: 0, width: 2560, height: 1415),
        safeAreaTop: 0,
        auxiliaryLeftWidth: nil,
        auxiliaryRightWidth: nil
    )

    @Test func notchFrameMatchesGapBetweenAuxiliaryAreas() {
        let layout = NotchGeometry.layout(for: notchedScreen, nonNotchMode: .pill)

        #expect(layout == .notch(CGRect(x: 751, y: 1074.5, width: 208, height: 37.5)))
    }

    @Test func notchedScreenIgnoresNonNotchMode() {
        let layout = NotchGeometry.layout(for: notchedScreen, nonNotchMode: .hidden)

        #expect(layout.frame?.width == 208)
    }

    @Test func externalScreenGetsCenteredPillInsideMenuBar() throws {
        let layout = NotchGeometry.layout(for: externalScreen, nonNotchMode: .pill)

        guard case .pill(let rect) = layout else {
            Issue.record("expected pill, got \(layout)")
            return
        }
        #expect(rect.midX == externalScreen.frame.midX)
        #expect(rect.maxY == externalScreen.frame.maxY - NotchGeometry.pillTopInset)
        #expect(rect.height == 25 - 2 * NotchGeometry.pillTopInset)
    }

    @Test func externalScreenHiddenWhenModeIsHidden() {
        let layout = NotchGeometry.layout(for: externalScreen, nonNotchMode: .hidden)

        #expect(layout == .none)
        #expect(layout.frame == nil)
    }

    @Test func pillFallsBackToDefaultHeightWhenMenuBarIsAutoHidden() throws {
        let autoHidden = ScreenMetrics(
            frame: externalScreen.frame,
            visibleFrame: externalScreen.frame,
            safeAreaTop: 0,
            auxiliaryLeftWidth: nil,
            auxiliaryRightWidth: nil
        )

        let rect = try #require(NotchGeometry.layout(for: autoHidden, nonNotchMode: .pill).frame)

        #expect(rect.height == NotchGeometry.defaultMenuBarHeight - 2 * NotchGeometry.pillTopInset)
    }

    @Test func screenWithSafeAreaButNoAuxiliaryAreasIsTreatedAsNonNotched() {
        let odd = ScreenMetrics(
            frame: notchedScreen.frame,
            visibleFrame: notchedScreen.visibleFrame,
            safeAreaTop: 37.5,
            auxiliaryLeftWidth: nil,
            auxiliaryRightWidth: nil
        )

        guard case .pill = NotchGeometry.layout(for: odd, nonNotchMode: .pill) else {
            Issue.record("expected pill fallback")
            return
        }
    }
}
