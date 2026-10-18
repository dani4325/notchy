import AppKit
import Testing
@testable import NotchCore

@MainActor
struct CompanionStoreTests {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("notchy-tests-\(UUID().uuidString)")
    let defaults = UserDefaults(suiteName: "notchy-tests-\(UUID().uuidString)")!

    func makePNG() throws -> URL {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    @Test func importCopiesFileAndLoadsImage() throws {
        let store = CompanionStore(directory: directory, defaults: defaults)
        let source = try makePNG()

        try store.importMedia(from: source)

        let stored = try #require(store.fileURL)
        #expect(stored.deletingLastPathComponent().path == directory.path)
        #expect(FileManager.default.fileExists(atPath: stored.path))
        #expect(store.image != nil)
    }

    @Test func importSurvivesReloadAndReplacesPreviousFile() throws {
        let store = CompanionStore(directory: directory, defaults: defaults)
        try store.importMedia(from: try makePNG())
        let first = try #require(store.fileURL)

        try store.importMedia(from: try makePNG())
        let reloaded = CompanionStore(directory: directory, defaults: defaults)

        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(reloaded.fileURL == store.fileURL)
        #expect(reloaded.image != nil)
    }

    @Test func clearRemovesFileAndImage() throws {
        let store = CompanionStore(directory: directory, defaults: defaults)
        try store.importMedia(from: try makePNG())
        let stored = try #require(store.fileURL)

        store.clear()

        #expect(store.image == nil)
        #expect(store.fileURL == nil)
        #expect(!FileManager.default.fileExists(atPath: stored.path))
    }

    @Test func importRejectsNonImageFiles() throws {
        let store = CompanionStore(directory: directory, defaults: defaults)
        let text = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        try Data("hola".utf8).write(to: text)

        #expect(throws: CompanionStore.ImportError.unreadableImage) {
            try store.importMedia(from: text)
        }
        #expect(store.image == nil)
    }
}
