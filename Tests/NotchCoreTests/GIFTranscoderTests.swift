import AVFoundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import NotchCore

struct GIFTranscoderTests {
    static let size = 64
    static let frameCount = 6
    static let delay = 0.1

    func makeGIF(transparent: Bool, frames: Int = GIFTranscoderTests.frameCount) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).gif")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for index in 0..<frames {
            let context = try #require(CGContext(
                data: nil, width: Self.size, height: Self.size, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            if !transparent {
                context.setFillColor(CGColor(srgbRed: 0.1, green: 0.2, blue: 0.6, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: Self.size, height: Self.size))
            }
            context.setFillColor(CGColor(srgbRed: 1, green: 0.5, blue: 0, alpha: 1))
            context.fill(CGRect(x: index * 8, y: 16, width: 24, height: 32))
            let image = try #require(context.makeImage())
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: Self.delay]] as CFDictionary)
        }
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    func firstVideoFrame(_ url: URL) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try await generator.image(at: .zero).image
    }

    func pixels(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        let context = try #require(CGContext(
            data: &bytes, width: Self.size, height: Self.size, bitsPerComponent: 8, bytesPerRow: Self.size * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: Self.size, height: Self.size))
        return bytes
    }

    @Test func manyConversionsAtTheSameTimeAllFinish() throws {
        let gif = try makeGIF(transparent: false)
        let count = ProcessInfo.processInfo.activeProcessorCount * 2
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<count {
                    group.addTask { _ = try? await GIFTranscoder.transcode(gif) }
                }
            }
            done.signal()
        }

        #expect(done.wait(timeout: .now() + 60) == .success)
    }

    @Test func opaqueGIFsBecomeH264VideosWithTheSameDuration() async throws {
        let gif = try makeGIF(transparent: false)

        let video = try await GIFTranscoder.transcode(gif)

        #expect(video.pathExtension == "mp4")
        let asset = AVURLAsset(url: video)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - Double(Self.frameCount) * Self.delay) < 0.02)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try #require(tracks.first)
        let codec = try await track.load(.formatDescriptions).first.map { CMFormatDescriptionGetMediaSubType($0) }
        #expect(codec == kCMVideoCodecType_H264)
        let source = try #require(CGImageSourceCreateWithURL(gif as CFURL, nil))
        let original = try pixels(try #require(CGImageSourceCreateImageAtIndex(source, 0, nil)))
        let converted = try pixels(try await firstVideoFrame(video))
        let difference = interiorColorIndices(original).map { abs(Int(original[$0]) - Int(converted[$0])) }.max() ?? 255
        #expect(difference <= GIFTranscoderTests.tolerance, "color: \(difference)")
    }

    @Test func transparentGIFsKeepTheirAlphaAsHEVC() async throws {
        let gif = try makeGIF(transparent: true)

        let video = try await GIFTranscoder.transcode(gif)

        #expect(video.pathExtension == "mov")
        let source = try #require(CGImageSourceCreateWithURL(gif as CFURL, nil))
        let firstFrame = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let original = try pixels(firstFrame)
        let converted = try pixels(try await firstVideoFrame(video))
        let alphaDifference = stride(from: 3, to: original.count, by: 4).map { abs(Int(original[$0]) - Int(converted[$0])) }.max() ?? 255
        #expect(alphaDifference <= GIFTranscoderTests.tolerance, "alfa: \(alphaDifference)")
        let interiorDifference = interiorColorIndices(original).filter { original[$0 - $0 % 4 + 3] == 255 }
            .map { abs(Int(original[$0]) - Int(converted[$0])) }.max() ?? 255
        #expect(interiorDifference <= GIFTranscoderTests.tolerance, "color: \(interiorDifference)")
    }

    static let tolerance = 8

    @Test func aConvertedVideoMatchesItsGIF() async throws {
        let gif = try makeGIF(transparent: false)
        let video = try await GIFTranscoder.transcode(gif)

        #expect(await GIFTranscoder.matches(video: video, gif: gif))
    }

    @Test func aVideoFromAnotherGIFDoesNotMatch() async throws {
        let gif = try makeGIF(transparent: false)
        let other = try makeGIF(transparent: false, frames: 3)
        let video = try await GIFTranscoder.transcode(other)

        #expect(await GIFTranscoder.matches(video: video, gif: gif) == false)
    }

    func interiorColorIndices(_ pixels: [UInt8]) -> [Int] {
        let radius = 2
        return (0..<(Self.size * Self.size)).filter { pixel in
            let x = pixel % Self.size, y = pixel / Self.size
            guard x >= radius, y >= radius, x < Self.size - radius, y < Self.size - radius else { return false }
            let center = pixels[pixel * 4..<pixel * 4 + 4]
            return (-radius...radius).allSatisfy { dy in (-radius...radius).allSatisfy { dx in
                let other = ((y + dy) * Self.size + x + dx) * 4
                return pixels[other..<other + 4].elementsEqual(center)
            } }
        }.flatMap { [$0 * 4, $0 * 4 + 1, $0 * 4 + 2] }
    }
}
