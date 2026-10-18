import CoreGraphics
import Testing
@testable import NotchCore

struct MenuCollisionTests {
    let primaryHeight: CGFloat = 1112
    let notch = CGRect(x: 751, y: 1074.5, width: 208, height: 37.5)

    var wingZones: [CGRect] {
        NotchGeometry.wingZones(collapsed: notch, wing: 45.5)
    }

    @Test func wingZonesAreTheTwoSidesOfTheCompactFrame() {
        #expect(wingZones == [
            CGRect(x: 705.5, y: 1074.5, width: 45.5, height: 37.5),
            CGRect(x: 959, y: 1074.5, width: 45.5, height: 37.5),
        ])
    }

    @Test func convertsAccessibilityTopLeftFrameToCocoaCoordinates() {
        let axFrame = CGRect(x: 960, y: 0, width: 50, height: 24)

        #expect(MenuCollision.cocoaFrame(fromAccessibility: axFrame, primaryScreenHeight: primaryHeight)
            == CGRect(x: 960, y: 1088, width: 50, height: 24))
    }

    @Test func menuRightOfTheNotchCollidesWithRightWing() {
        let help = MenuCollision.cocoaFrame(fromAccessibility: CGRect(x: 965, y: 0, width: 52, height: 24), primaryScreenHeight: primaryHeight)

        #expect(MenuCollision.collides(menuItems: [help], wingZones: wingZones))
    }

    @Test func shortMenuBarDoesNotCollide() {
        let items = (0..<8).map { index in
            MenuCollision.cocoaFrame(
                fromAccessibility: CGRect(x: 10 + CGFloat(index) * 70, y: 0, width: 60, height: 24),
                primaryScreenHeight: primaryHeight
            )
        }

        #expect(!MenuCollision.collides(menuItems: items, wingZones: wingZones))
    }
}
