import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import NotchCore

enum GIFFixture {
    static func make(frames: Int = 4, delay: Double = 0.1, side: Int = 40) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fixture-\(UUID().uuidString).gif")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for index in 0..<frames {
            let context = try #require(CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.setFillColor(CGColor(srgbRed: Double(index) / Double(frames), green: 0.4, blue: 0.8, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let frame = try #require(context.makeImage())
            CGImageDestinationAddImage(destination, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
        }
        #expect(CGImageDestinationFinalize(destination))
        return url
    }
}

struct AnimatedImageDecoderTests {
    @Test func decodesEveryFrameWithItsDelay() throws {
        let url = try GIFFixture.make(frames: 4, delay: 0.1)

        let animation = try #require(AnimatedImageDecoder.decode(url: url, maxPixelSize: 200))

        #expect(animation.frames.count == 4)
        #expect(abs(animation.duration - 0.4) < 0.001)
        #expect(animation.keyTimes.first == 0)
        #expect(animation.keyTimes.count == 5)
        #expect(abs((animation.keyTimes.last ?? 0) - 1) < 0.0001)
    }

    @Test func tooShortDelaysUseTheBrowserDefault() throws {
        let url = try GIFFixture.make(frames: 2, delay: 0.01)

        let animation = try #require(AnimatedImageDecoder.decode(url: url, maxPixelSize: 200))

        #expect(abs(animation.duration - 2 * AnimatedImageDecoder.fallbackDelay) < 0.001)
    }

    @Test func framesAreDownsampledToTheRequestedSize() throws {
        let url = try GIFFixture.make(frames: 2, side: 400)

        let animation = try #require(AnimatedImageDecoder.decode(url: url, maxPixelSize: 100))

        #expect(animation.frames.allSatisfy { max($0.width, $0.height) <= 100 })
        #expect(animation.aspect == 1)
    }
}

@MainActor
struct AnimatedLayerViewTests {
    @Test func activeAnimationRunsAndInactiveFreezesWithoutRemovingIt() async throws {
        let url = try GIFFixture.make()
        let view = MediaContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 120, height: 120)

        view.configure(source: MediaSource(url: url, kind: .animatedImage), crop: .standard, isActive: true)
        try await view.waitUntilLoaded()

        let layer = try #require(view.animatedLayerForTesting)
        #expect(layer.animation(forKey: MediaContainerView.frameAnimationKey) != nil)
        #expect(layer.speed == 1)

        view.configure(source: MediaSource(url: url, kind: .animatedImage), crop: .standard, isActive: false)
        #expect(layer.speed == 0)
        #expect(layer.animation(forKey: MediaContainerView.frameAnimationKey) != nil)

        view.configure(source: MediaSource(url: url, kind: .animatedImage), crop: .standard, isActive: true)
        #expect(layer.speed == 1)
    }

    @Test func staticImagesNeverAnimate() async throws {
        let url = try GIFFixture.make(frames: 1)
        let view = MediaContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 120, height: 120)

        view.configure(source: MediaSource(url: url, kind: .image), crop: .standard, isActive: true)
        try await view.waitUntilLoaded()

        #expect(view.animatedLayerForTesting?.animation(forKey: MediaContainerView.frameAnimationKey) == nil)
        #expect(view.animatedLayerForTesting?.contents != nil)
    }
}
