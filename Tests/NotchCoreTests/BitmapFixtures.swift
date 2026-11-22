import AppKit

extension NSColor {
    var bitmapPixel: NSColor {
        guard let srgb = usingColorSpace(.sRGB) else { return self }
        return NSColor(deviceRed: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent, alpha: srgb.alphaComponent)
    }
}
