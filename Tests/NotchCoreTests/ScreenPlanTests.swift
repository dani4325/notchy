import CoreGraphics
import Testing
@testable import NotchCore

struct ScreenPlanTests {
    let builtIn = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1710, height: 1112),
        visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1074),
        safeAreaTop: 37.5, auxiliaryLeftWidth: 751, auxiliaryRightWidth: 751
    )
    let external = ScreenMetrics(
        frame: CGRect(x: 1710, y: -200, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 1710, y: -200, width: 2560, height: 1415),
        safeAreaTop: 0, auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil
    )

    @Test func builtInGetsNotchAndExternalGetsPillOnItsOwnTopEdge() throws {
        let plan = ScreenPlan.islands(for: [(1, builtIn), (2, external)], nonNotchMode: .pill)

        #expect(plan.count == 2)
        let notch = try #require(plan.first { $0.displayID == 1 })
        let pill = try #require(plan.first { $0.displayID == 2 })
        #expect(notch.kind == .notch)
        #expect(pill.kind == .pill)
        #expect(pill.collapsedFrame.maxY == external.frame.maxY - NotchGeometry.pillTopInset)
        #expect(external.frame.contains(CGPoint(x: pill.collapsedFrame.midX, y: pill.collapsedFrame.midY)))
    }

    @Test func hiddenModeKeepsOnlyTheNotch() {
        let plan = ScreenPlan.islands(for: [(1, builtIn), (2, external)], nonNotchMode: .hidden)

        #expect(plan.map(\.displayID) == [1])
    }

    @Test func resolutionChangeMovesTheIslandToTheNewNotch() throws {
        let scaled = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1496, height: 967),
            visibleFrame: CGRect(x: 0, y: 0, width: 1496, height: 934),
            safeAreaTop: 32, auxiliaryLeftWidth: 655, auxiliaryRightWidth: 655
        )

        let island = try #require(ScreenPlan.islands(for: [(1, scaled)], nonNotchMode: .pill).first)

        #expect(island.collapsedFrame == CGRect(x: 655, y: 935, width: 186, height: 32))
        #expect(island.stripHeight == 33)
    }

    @Test func clamshellWithOnlyExternalShowsPill() {
        let plan = ScreenPlan.islands(for: [(2, external)], nonNotchMode: .pill)

        #expect(plan.map(\.kind) == [.pill])
    }
}
