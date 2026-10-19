import Foundation
import Testing
@testable import NotchCore

@MainActor
struct GIFMigrationTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-migration-\(UUID().uuidString)")
    let defaults = UserDefaults(suiteName: "notchy-migration-\(UUID().uuidString)")!
    var trash: FakeTrash { FakeTrash(root: directory) }

    func makeStore() -> ThemeStore { ThemeStore(directory: directory, defaults: defaults, trash: trash.move) }

    func trashedFiles() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: trash.folder.path)) ?? []
    }

    @Test func gifBackgroundsBecomeVideosAndTheGIFGoesToTheTrash() async throws {
        let store = makeStore()
        let theme = try store.createTheme(named: "Con GIF")
        var withGIF = try store.setBackground(from: try GIFTranscoderTests().makeGIF(transparent: false), themeID: theme.id)
        withGIF.background?.media.crop = MediaCrop(zoom: 1.5, focusX: 0.3, focusY: 0.6)
        withGIF.background?.legibility = 0.4
        try store.save(withGIF)
        let gifFile = store.mediaURL(themeID: theme.id, media: try #require(withGIF.background?.media))

        await store.migrateGIFBackgrounds()

        let migrated = try #require(store.theme(id: theme.id)?.background)
        #expect(migrated.media.kind == .video)
        #expect(migrated.media.crop == MediaCrop(zoom: 1.5, focusX: 0.3, focusY: 0.6))
        #expect(migrated.legibility == 0.4)
        #expect(FileManager.default.fileExists(atPath: store.mediaURL(themeID: theme.id, media: migrated.media).path))
        #expect(!FileManager.default.fileExists(atPath: gifFile.path))
        #expect(trashedFiles().contains { $0.hasSuffix(gifFile.lastPathComponent) })
        #expect(store.measurement(themeID: theme.id) != nil)
        #expect(makeStore().theme(id: theme.id)?.background?.media.kind == .video)
    }

    @Test func aGIFThatCannotBeConvertedIsLeftUntouched() async throws {
        let store = makeStore()
        let theme = try store.createTheme(named: "GIF dañado")
        let withGIF = try store.setBackground(from: try GIFTranscoderTests().makeGIF(transparent: false), themeID: theme.id)
        let media = try #require(withGIF.background?.media)
        let gifFile = store.mediaURL(themeID: theme.id, media: media)
        let damaged = try Data(contentsOf: gifFile).prefix(40)
        try damaged.write(to: gifFile)

        await store.migrateGIFBackgrounds()

        #expect(store.theme(id: theme.id)?.background?.media == media)
        #expect(try Data(contentsOf: gifFile) == damaged)
        #expect(trashedFiles().isEmpty)
    }

    @Test func gifCompanionsBecomeVideos() async throws {
        let companionTrash = FakeTrash(root: directory.appendingPathComponent("companion"))
        let companion = CompanionStore(directory: directory.appendingPathComponent("companion"), defaults: defaults, trash: companionTrash.move)
        try companion.importMedia(from: try GIFTranscoderTests().makeGIF(transparent: true))
        let gifFile = try #require(companion.source?.url)

        await companion.migrateGIF()

        #expect(companion.source?.kind == .video)
        #expect(!FileManager.default.fileExists(atPath: gifFile.path))
        #expect(((try? FileManager.default.contentsOfDirectory(atPath: companionTrash.folder.path)) ?? []).count == 1)
    }
}
