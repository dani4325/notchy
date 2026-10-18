import CoreGraphics
import Testing
@testable import NotchCore

struct HoverRegionTests {
    let notch = CGRect(x: 751, y: 1074.5, width: 208, height: 37.5)
    let expanded = CGRect(x: 605, y: 942, width: 500, height: 170)

    @Test func collapsedAndCompactOnlyReactOnTheNotchItself() {
        #expect(NotchGeometry.hoverRegions(expanded: false, collapsed: notch, expandedFrame: expanded, stripHeight: 38) == [notch])
    }

    @Test func expandedReactsOnStemAndBodyButNotOnMenuBarSides() {
        let regions = NotchGeometry.hoverRegions(expanded: true, collapsed: notch, expandedFrame: expanded, stripHeight: 38)

        #expect(regions == [
            CGRect(x: 751, y: 1074, width: 208, height: 38),
            CGRect(x: 605, y: 942, width: 500, height: 132),
        ])
    }
}

struct StripHeightTests {
    @Test func stripReachesFromIslandTopToMenuBarBottom() {
        let screen = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1710, height: 1112),
            visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1074),
            safeAreaTop: 37.5, auxiliaryLeftWidth: 751, auxiliaryRightWidth: 751
        )
        let notch = CGRect(x: 751, y: 1074.5, width: 208, height: 37.5)

        #expect(NotchGeometry.stripHeight(collapsed: notch, screen: screen) == 38)
    }

    @Test func autoHiddenMenuBarFallsBackToIslandHeight() {
        let screen = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            safeAreaTop: 0, auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil
        )
        let pill = CGRect(x: 1188, y: 1418, width: 184, height: 20)

        #expect(NotchGeometry.stripHeight(collapsed: pill, screen: screen) == 20)
    }
}
