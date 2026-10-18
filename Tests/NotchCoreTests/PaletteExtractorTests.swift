import CoreGraphics
import Testing
@testable import NotchCore

struct PaletteExtractorTests {
    func twoColorImage() throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 0.9, green: 0.1, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        context.setFillColor(CGColor(srgbRed: 0.1, green: 0.2, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 32, y: 0, width: 32, height: 32))
        return try #require(context.makeImage())
    }

    @Test func findsTheDominantColorsOfAnImage() throws {
        let clusters = PaletteExtractor.clusters(from: try twoColorImage(), count: 4)

        let hasRed = clusters.contains { $0.color.red > 0.7 && $0.color.blue < 0.3 && $0.weight > 0.2 }
        let hasBlue = clusters.contains { $0.color.blue > 0.7 && $0.color.red < 0.3 && $0.weight > 0.2 }
        #expect(hasRed)
        #expect(hasBlue)
    }
}
