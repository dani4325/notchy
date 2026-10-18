import CoreGraphics
import Testing
@testable import NotchCore

struct IslandGeometryTests {
    let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
    let notch = CGRect(x: 751, y: 1074.5, width: 208, height: 37.5)

    @Test func expandedFrameIsTopAlignedAndCenteredOnNotch() {
        let frame = NotchGeometry.expandedFrame(
            collapsed: notch,
            size: CGSize(width: 500, height: 170),
            screen: screen
        )

        #expect(frame == CGRect(x: 605, y: 942, width: 500, height: 170))
    }

    @Test func expandedFrameNeverShrinksBelowCollapsedSize() {
        let frame = NotchGeometry.expandedFrame(
            collapsed: notch,
            size: CGSize(width: 100, height: 20),
            screen: screen
        )

        #expect(frame.width == notch.width)
        #expect(frame.height == notch.height)
        #expect(frame.maxY == notch.maxY)
    }

    @Test func expandedFrameIsClampedInsideScreen() {
        let nearEdge = CGRect(x: 1700, y: 1086, width: 10, height: 24)

        let frame = NotchGeometry.expandedFrame(
            collapsed: nearEdge,
            size: CGSize(width: 500, height: 170),
            screen: screen
        )

        #expect(frame.maxX == screen.maxX)
        #expect(frame.maxY == nearEdge.maxY)
    }
}

struct CompactGeometryTests {
    @Test func compactFrameAddsSymmetricWingsKeepingTopAndHeight() {
        let notch = CGRect(x: 751, y: 1074.5, width: 208, height: 37.5)

        let frame = NotchGeometry.compactFrame(collapsed: notch, wing: 44)

        #expect(frame == CGRect(x: 707, y: 1074.5, width: 296, height: 37.5))
    }
}
