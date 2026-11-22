import AppKit
import Foundation
import ImageIO
import Testing
@testable import NotchCore

@MainActor
struct ArtworkBackdropTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-artwork-\(UUID().uuidString)")

    func cover(top: NSColor, bottom: NSColor, side: Int = 64) throws -> Data {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        for x in 0..<side { for y in 0..<side { rep.setColor((y < side / 2 ? top : bottom).bitmapPixel, atX: x, y: y) } }
        return try #require(rep.representation(using: .png, properties: [:]))
    }

    @Test func aCoverBecomesABackgroundWithItsOwnColorsAndAMeasurement() async throws {
        let backdrop = ArtworkBackdrop(directory: directory)

        await backdrop.prepare(artwork: try cover(top: .systemYellow, bottom: .systemBlue))

        let prepared = try #require(backdrop.prepared)
        #expect(FileManager.default.fileExists(atPath: prepared.url.path))
        #expect(prepared.palette.source == .automatic)
        #expect(prepared.crop == prepared.crop.sanitized())
        #expect(prepared.crop.zoom == 1)
    }

    @Test func noCoverClearsTheBackgroundAndItsFile() async throws {
        let backdrop = ArtworkBackdrop(directory: directory)
        await backdrop.prepare(artwork: try cover(top: .white, bottom: .black))
        let file = try #require(backdrop.prepared).url

        await backdrop.prepare(artwork: nil)

        #expect(backdrop.prepared == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func aNewCoverReplacesTheOldFile() async throws {
        let backdrop = ArtworkBackdrop(directory: directory)
        await backdrop.prepare(artwork: try cover(top: .white, bottom: .black))
        let first = try #require(backdrop.prepared).url

        await backdrop.prepare(artwork: try cover(top: .red, bottom: .green))

        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(try #require(backdrop.prepared).url != first)
    }

    @Test func unreadableArtworkLeavesNoBackground() async {
        let backdrop = ArtworkBackdrop(directory: directory)

        await backdrop.prepare(artwork: Data("no es una imagen".utf8))

        #expect(backdrop.prepared == nil)
    }

    @Test func theCoverThemeUsesTheCoverWhileMusicHasOneAndNotchyBlackOtherwise() async throws {
        let backdrop = ArtworkBackdrop(directory: directory)
        await backdrop.prepare(artwork: try cover(top: .systemYellow, bottom: .systemBlue))
        let prepared = try #require(backdrop.prepared)

        let withCover = ThemeAppearance.resolve(.caratula, artwork: prepared)
        let withoutCover = ThemeAppearance.resolve(.caratula, artwork: nil)

        #expect(withCover.background?.url == prepared.url)
        #expect(withCover.theme.palette == prepared.palette)
        #expect(withCover.measurement != nil)
        #expect(withoutCover.background == nil)
        #expect(withoutCover.theme.palette == Theme.notchyDefault.palette)
    }

    @Test func otherThemesIgnoreTheCover() async throws {
        let backdrop = ArtworkBackdrop(directory: directory)
        await backdrop.prepare(artwork: try cover(top: .systemYellow, bottom: .systemBlue))

        let appearance = ThemeAppearance.resolve(.cartel, artwork: backdrop.prepared)

        #expect(appearance.background == nil)
        #expect(appearance.theme.palette == Theme.cartel.palette)
    }
}
