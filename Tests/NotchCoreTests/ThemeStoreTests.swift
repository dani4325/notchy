import AppKit
import Testing
@testable import NotchCore

@MainActor
struct ThemeStoreTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-themes-\(UUID().uuidString)")
    let defaults = UserDefaults(suiteName: "notchy-themes-\(UUID().uuidString)")!

    func makeStore() -> ThemeStore {
        ThemeStore(directory: directory, defaults: defaults, trash: FakeTrash(root: directory).move)
    }

    @Test func deletingMovesTheThemeToTheTrashAndUndoBringsItBack() throws {
        let store = makeStore()
        let theme = try store.createTheme(named: "Temporal")

        let trashed = try store.delete(themeID: theme.id)

        #expect(store.theme(id: theme.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: store.folder(for: theme.id).path))
        #expect(FileManager.default.fileExists(atPath: trashed.path))

        try store.restore(themeID: theme.id, from: trashed)

        #expect(store.theme(id: theme.id)?.name == "Temporal")
        #expect(!FileManager.default.fileExists(atPath: trashed.path))
    }

    @Test func unreadableThemesAreCountedInsteadOfVanishingSilently() throws {
        let broken = directory.appendingPathComponent("roto")
        try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
        _ = makeStore()
        try Data("{ esto no es un tema".utf8).write(to: broken.appendingPathComponent(ThemeStore.themeFileName))

        #expect(makeStore().unreadableThemes == 1)
    }

    func makePNG(color: NSColor = .red) throws -> URL {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        for x in 0..<8 { for y in 0..<4 { rep.setColor(color.bitmapPixel, atX: x, y: y) } }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    @Test func aFreshInstallStartsOnTheBuiltInDefaultWithoutWritingThemes() {
        let store = makeStore()

        #expect(store.themes.first?.id == Theme.notchyDefault.id)
        #expect(store.themes.allSatisfy { store.isBuiltIn($0.id) })
        #expect(store.activeTheme.id == Theme.notchyDefault.id)
        #expect(!FileManager.default.fileExists(atPath: store.folder(for: Theme.notchyDefault.id).path))
    }

    @Test func savePersistsSanitizedThemeAcrossReloads() throws {
        let store = makeStore()
        var theme = try store.createTheme(named: "Borrador")
        store.activate(themeID: theme.id)
        theme.name = "  Mi tema  "
        theme.shape.widthRatio = 99

        try store.save(theme)
        let reloaded = makeStore()

        #expect(reloaded.activeTheme.name == "Mi tema")
        #expect(reloaded.activeTheme.shape.widthRatio == ThemeShape.widthRange.upperBound)
    }

    @Test func duplicateCreatesAnIndependentThemeWithItsMedia() throws {
        let store = makeStore()
        let original = try store.createTheme(named: "Fondo")
        _ = try store.setBackground(from: try makePNG(), themeID: original.id)

        let copy = try store.duplicate(themeID: original.id)

        #expect(copy.id != original.id)
        #expect(copy.name == "Fondo (copia)")
        let media = try #require(copy.background?.media)
        #expect(FileManager.default.fileExists(atPath: store.mediaURL(themeID: copy.id, media: media).path))
        #expect(store.themes.filter { !store.isBuiltIn($0.id) }.count == 2)
    }

    @Test func deletingTheActiveThemeFallsBackToTheDefault() throws {
        let store = makeStore()
        let theme = try store.createTheme(named: "Único")
        store.activate(themeID: theme.id)

        _ = try store.delete(themeID: theme.id)

        #expect(store.activeTheme.id == Theme.notchyDefault.id)
        #expect(!FileManager.default.fileExists(atPath: store.folder(for: theme.id).path))
    }

    @Test func builtInThemesCannotBeDeletedOrGetABackground() throws {
        let store = makeStore()

        #expect(throws: ThemeStore.StoreError.builtInTheme) {
            _ = try store.delete(themeID: Theme.notchyDefault.id)
        }
        #expect(throws: ThemeStore.StoreError.builtInTheme) {
            try store.setBackground(from: try makePNG(), themeID: Theme.notchyDefault.id)
        }
    }

    @Test func setBackgroundCopiesMediaAndRemovesThePreviousFile() throws {
        let store = makeStore()
        let theme = try store.createTheme(named: "Fondo")
        let first = try store.setBackground(from: try makePNG(), themeID: theme.id)
        let firstURL = store.mediaURL(themeID: first.id, media: try #require(first.background?.media))

        let second = try store.setBackground(from: try makePNG(color: .blue), themeID: theme.id)

        let media = try #require(second.background?.media)
        #expect(media.kind == .image)
        #expect(media.crop == .standard)
        #expect(FileManager.default.fileExists(atPath: store.mediaURL(themeID: second.id, media: media).path))
        #expect(!FileManager.default.fileExists(atPath: firstURL.path))
    }

    @Test func setBackgroundRejectsUnsupportedFiles() throws {
        let store = makeStore()
        let theme = try store.createTheme(named: "Fondo")
        let text = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        try Data("hola".utf8).write(to: text)

        #expect(throws: ThemeStore.StoreError.unsupportedMedia) {
            try store.setBackground(from: text, themeID: theme.id)
        }
    }

    @Test func archiveRoundTripCreatesANewThemeWithMedia() throws {
        let store = makeStore()
        let created = try store.createTheme(named: "Para exportar")
        var theme = try store.setBackground(from: try makePNG(), themeID: created.id)
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
        #expect(!ThemeArchive.isSafeEntry("media/a\u{0}b"))
        #expect(!ThemeArchive.isSafeEntry("media/a\u{1}b"))
        #expect(!ThemeArchive.isSafeEntry("../\u{301}x"))
        #expect(!ThemeArchive.isSafeEntry("./theme.json"))
        #expect(!ThemeArchive.isSafeEntry("media/./bg.png"))
        #expect(!ThemeArchive.isSafeEntry("media//bg.png"))
        #expect(ThemeArchive.isSafeEntry("media/"))
        #expect(ThemeArchive.isSafeEntry("media/fondo ñ 1.png"))
    }

    func understatingSizes(of archive: URL, declaredSize: UInt32) throws -> URL {
        var bytes = [UInt8](try Data(contentsOf: archive))
        let centralHeader: [UInt8] = [0x50, 0x4B, 0x01, 0x02]
        for offset in 0..<(bytes.count - 28) where Array(bytes[offset..<offset + 4]) == centralHeader {
            withUnsafeBytes(of: declaredSize.littleEndian) { bytes.replaceSubrange(offset + 24..<offset + 28, with: $0) }
        }
        let patched = archive.deletingPathExtension().appendingPathExtension("lying.notchytheme")
        try Data(bytes).write(to: patched)
        return patched
    }

    @Test func extractionCountsRealBytesWhenTheArchiveUnderstatesSizes() throws {
        let realSize = 2 * 1024 * 1024
        let honest = try zip { folder in
            try JSONEncoder().encode(Theme.notchyDefault).write(to: folder.appendingPathComponent("theme.json"))
            let media = folder.appendingPathComponent("media")
            try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
            try Data(count: realSize).write(to: media.appendingPathComponent("big.bin"))
        }
        let lying = try understatingSizes(of: honest, declaredSize: 10)
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        #expect(throws: ThemeArchive.ArchiveError.tooLarge) {
            _ = try ThemeArchive.extract(lying, maximumBytes: realSize / 2, workingDirectory: workspace)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: workspace.path).isEmpty)
    }

    @Test func extractionRestoresFilesOfAnHonestArchive() throws {
        let archive = try zip { folder in
            try JSONEncoder().encode(Theme.notchyDefault).write(to: folder.appendingPathComponent("theme.json"))
        }

        let (theme, folder) = try ThemeArchive.extract(archive)
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(theme.name == Theme.notchyDefault.name)
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

@MainActor
struct ThemeMeasurementStorageTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-measure-\(UUID().uuidString)")
    let defaults = UserDefaults(suiteName: "notchy-measure-\(UUID().uuidString)")!

    func makeStore() -> ThemeStore { ThemeStore(directory: directory, defaults: defaults, trash: FakeTrash(root: directory).move) }

    func makePNG(white: Bool) throws -> URL {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 16, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        for x in 0..<16 { for y in 0..<8 { rep.setColor((white ? NSColor.white : .black).bitmapPixel, atX: x, y: y) } }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    func measured(_ url: URL) async throws -> BackgroundMeasurement {
        try #require(await BackgroundMeasurer.measure(url, kind: .image))
    }

    @Test func theMeasurementIsSavedWithTheBackgroundAndSurvivesARestart() async throws {
        let store = makeStore()
        let theme = try store.createTheme(named: "Con fondo")
        let image = try makePNG(white: true)
        let measurement = try await measured(image)

        _ = try store.setBackground(from: image, themeID: theme.id, measurement: measurement)

        #expect(store.measurement(themeID: theme.id) == measurement)
        #expect(makeStore().measurement(themeID: theme.id) == measurement)
    }

    @Test func themesWithoutAMeasurementAreMeasuredInTheBackground() async throws {
        let store = makeStore()
        let theme = try store.createTheme(named: "Antiguo")
        _ = try store.setBackground(from: try makePNG(white: true), themeID: theme.id)
        #expect(store.measurement(themeID: theme.id) == nil)

        await store.measureMissing()

        #expect(store.measurement(themeID: theme.id) != nil)
        #expect(makeStore().measurement(themeID: theme.id) != nil)
    }

    @Test func clearingTheBackgroundRemovesItsMeasurement() async throws {
        let store = makeStore()
        let theme = try store.createTheme(named: "Sin fondo")
        let image = try makePNG(white: false)
        let updated = try store.setBackground(from: image, themeID: theme.id, measurement: try await measured(image))
        let file = store.measurementURL(themeID: theme.id, media: try #require(updated.background?.media))

        _ = try store.clearBackground(themeID: theme.id)

        #expect(store.measurement(themeID: theme.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func duplicatesKeepTheMeasurement() async throws {
        let store = makeStore()
        let theme = try store.createTheme(named: "Original")
        let image = try makePNG(white: true)
        _ = try store.setBackground(from: image, themeID: theme.id, measurement: try await measured(image))

        let copy = try store.duplicate(themeID: theme.id)

        #expect(store.measurement(themeID: copy.id) == store.measurement(themeID: theme.id))
    }

    @Test func importedArchivesCannotBringTheirOwnMeasurement() async throws {
        let store = makeStore()
        let theme = try store.createTheme(named: "Para exportar")
        let image = try makePNG(white: true)
        let real = try await measured(image)
        let updated = try store.setBackground(from: image, themeID: theme.id, measurement: real)
        let fake = BackgroundMeasurement(sample: try #require(await measured(try makePNG(white: false))).sample, framesChecked: 1, coversEveryFrame: true)
        try JSONEncoder().encode(fake).write(to: store.measurementURL(themeID: theme.id, media: try #require(updated.background?.media)))
        let archive = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).notchytheme")
        let folder = store.folder(for: theme.id)
        try ThemeArchive.compress(folder: folder, to: archive)

        let imported = try store.importArchive(from: archive)
        #expect(store.measurement(themeID: imported.id) == nil)

        await store.measureMissing()
        #expect(store.measurement(themeID: imported.id) == real)
    }
}

struct FakeTrash {
    let folder: URL

    init(root: URL) {
        folder = root.deletingLastPathComponent().appendingPathComponent(root.lastPathComponent + "-papelera")
    }

    func move(_ url: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }
}
