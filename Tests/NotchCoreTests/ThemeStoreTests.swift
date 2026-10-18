import AppKit
import Testing
@testable import NotchCore

@MainActor
struct ThemeStoreTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-themes-\(UUID().uuidString)")
    let defaults = UserDefaults(suiteName: "notchy-themes-\(UUID().uuidString)")!

    func makeStore() -> ThemeStore {
        ThemeStore(directory: directory, defaults: defaults)
    }

    func makePNG(color: NSColor = .red) throws -> URL {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        for x in 0..<8 { for y in 0..<4 { rep.setColor(color, atX: x, y: y) } }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    @Test func seedsTheDefaultThemeOnFirstLaunch() {
        let store = makeStore()

        #expect(store.themes.map(\.id) == [Theme.notchyDefault.id])
        #expect(store.activeTheme.id == Theme.notchyDefault.id)
        #expect(FileManager.default.fileExists(atPath: store.folder(for: Theme.notchyDefault.id).appendingPathComponent("theme.json").path))
    }

    @Test func savePersistsSanitizedThemeAcrossReloads() throws {
        let store = makeStore()
        var theme = store.activeTheme
        theme.name = "  Mi tema  "
        theme.shape.widthRatio = 99

        try store.save(theme)
        let reloaded = makeStore()

        #expect(reloaded.activeTheme.name == "Mi tema")
        #expect(reloaded.activeTheme.shape.widthRatio == ThemeShape.widthRange.upperBound)
    }

    @Test func duplicateCreatesAnIndependentThemeWithItsMedia() throws {
        let store = makeStore()
        _ = try store.setBackground(from: try makePNG(), themeID: Theme.notchyDefault.id)

        let copy = try store.duplicate(themeID: Theme.notchyDefault.id)

        #expect(copy.id != Theme.notchyDefault.id)
        #expect(copy.name == "Notchy (copia)")
        let media = try #require(copy.background?.media)
        #expect(FileManager.default.fileExists(atPath: store.mediaURL(themeID: copy.id, media: media).path))
        #expect(store.themes.count == 2)
    }

    @Test func deletingTheActiveThemeActivatesAnother() throws {
        let store = makeStore()
        let copy = try store.duplicate(themeID: Theme.notchyDefault.id)
        store.activate(themeID: copy.id)

        try store.delete(themeID: copy.id)

        #expect(store.activeTheme.id == Theme.notchyDefault.id)
        #expect(!FileManager.default.fileExists(atPath: store.folder(for: copy.id).path))
    }

    @Test func theLastThemeCannotBeDeleted() {
        let store = makeStore()

        #expect(throws: ThemeStore.StoreError.lastTheme) {
            try store.delete(themeID: Theme.notchyDefault.id)
        }
    }

    @Test func setBackgroundCopiesMediaAndRemovesThePreviousFile() throws {
        let store = makeStore()
        let first = try store.setBackground(from: try makePNG(), themeID: Theme.notchyDefault.id)
        let firstURL = store.mediaURL(themeID: first.id, media: try #require(first.background?.media))

        let second = try store.setBackground(from: try makePNG(color: .blue), themeID: Theme.notchyDefault.id)

        let media = try #require(second.background?.media)
        #expect(media.kind == .image)
        #expect(media.crop == .standard)
        #expect(FileManager.default.fileExists(atPath: store.mediaURL(themeID: second.id, media: media).path))
        #expect(!FileManager.default.fileExists(atPath: firstURL.path))
    }

    @Test func setBackgroundRejectsUnsupportedFiles() throws {
        let store = makeStore()
        let text = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        try Data("hola".utf8).write(to: text)

        #expect(throws: ThemeStore.StoreError.unsupportedMedia) {
            try store.setBackground(from: text, themeID: Theme.notchyDefault.id)
        }
    }

    @Test func archiveRoundTripCreatesANewThemeWithMedia() throws {
        let store = makeStore()
        var theme = try store.setBackground(from: try makePNG(), themeID: Theme.notchyDefault.id)
        theme.name = "Exportado"
        try store.save(theme)
        let archive = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).notchytheme")

        try store.exportArchive(themeID: theme.id, to: archive)
        let imported = try store.importArchive(from: archive)

        #expect(imported.id != theme.id)
        #expect(imported.name == "Exportado")
        #expect(imported.palette == theme.palette)
        let media = try #require(imported.background?.media)
        #expect(FileManager.default.fileExists(atPath: store.mediaURL(themeID: imported.id, media: media).path))
    }
}

struct ThemeArchiveTests {
    func zip(_ build: (URL) throws -> Void) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("arch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try build(folder)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).notchytheme")
        try ThemeArchive.compress(folder: folder, to: output)
        return output
    }

    @Test func entryNamesWithTraversalOrAbsolutePathsAreUnsafe() {
        #expect(ThemeArchive.isSafeEntry("theme.json"))
        #expect(ThemeArchive.isSafeEntry("media/bg.png"))
        #expect(!ThemeArchive.isSafeEntry("../evil"))
        #expect(!ThemeArchive.isSafeEntry("media/../../evil"))
        #expect(!ThemeArchive.isSafeEntry("/etc/passwd"))
        #expect(!ThemeArchive.isSafeEntry("media\\\\evil"))
    }

    @Test func archiveWithoutThemeFileIsRejected() throws {
        let archive = try zip { folder in
            try Data("x".utf8).write(to: folder.appendingPathComponent("readme.txt"))
        }

        #expect(throws: ThemeArchive.ArchiveError.missingThemeFile) {
            _ = try ThemeArchive.extract(archive)
        }
    }

    @Test func archiveContainingSymlinksIsRejected() throws {
        let archive = try zip { folder in
            try JSONEncoder().encode(Theme.notchyDefault).write(to: folder.appendingPathComponent("theme.json"))
            try FileManager.default.createSymbolicLink(
                at: folder.appendingPathComponent("link"), withDestinationURL: URL(fileURLWithPath: "/etc/hosts")
            )
        }

        #expect(throws: ThemeArchive.ArchiveError.unsafeContent) {
            _ = try ThemeArchive.extract(archive)
        }
    }
}

struct MediaKindTests {
    @Test func moviesAreDetectedAsVideoByType() throws {
        let clip = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        try Data().write(to: clip)

        #expect(try MediaKind.detect(at: clip) == .video)
    }
}
