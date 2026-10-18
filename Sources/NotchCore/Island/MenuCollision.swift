import CoreGraphics

enum MenuCollision {
    static let margin: CGFloat = 4

    static func cocoaFrame(fromAccessibility frame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryScreenHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    static func collides(menuItems: [CGRect], wingZones: [CGRect]) -> Bool {
        menuItems.contains { item in
            wingZones.contains { $0.insetBy(dx: -margin, dy: 0).intersects(item) }
        }
    }
}
