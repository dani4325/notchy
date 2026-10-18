import AppKit

public enum MenuBarIcon {
    public static let image: NSImage = {
        let size = NSSize(width: 20, height: 14)
        let image = NSImage(size: size, flipped: false) { rect in
            let body = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1.5), xRadius: 3, yRadius: 3)
            body.lineWidth = 1.5
            NSColor.black.setStroke()
            body.stroke()

            let notch = NSRect(x: rect.midX - 4, y: rect.maxY - 5.5, width: 8, height: 4)
            NSBezierPath(roundedRect: notch, xRadius: 1.5, yRadius: 1.5).fill()

            let spark = NSBezierPath()
            let center = NSPoint(x: rect.maxX - 5.5, y: rect.minY + 5)
            spark.move(to: NSPoint(x: center.x, y: center.y + 2.5))
            spark.line(to: NSPoint(x: center.x + 0.7, y: center.y + 0.7))
            spark.line(to: NSPoint(x: center.x + 2.5, y: center.y))
            spark.line(to: NSPoint(x: center.x + 0.7, y: center.y - 0.7))
            spark.line(to: NSPoint(x: center.x, y: center.y - 2.5))
            spark.line(to: NSPoint(x: center.x - 0.7, y: center.y - 0.7))
            spark.line(to: NSPoint(x: center.x - 2.5, y: center.y))
            spark.line(to: NSPoint(x: center.x - 0.7, y: center.y + 0.7))
            spark.close()
            spark.fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
