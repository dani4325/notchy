import Foundation
import Testing
@testable import NotchCore

@MainActor
struct ShelfStoreTests {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-shelf-\(UUID().uuidString)")
    var storage: URL { root.appendingPathComponent("storage") }
    var files: URL { root.appendingPathComponent("files") }

    func makeFile(_ name: String, contents: String = "hola") throws -> URL {
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        let url = files.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func makeStore(limit: Int = 3) -> ShelfStore {
        ShelfStore(directory: storage, limit: limit)
    }

    @Test func addingFilesKeepsReferencesNotCopies() throws {
        let store = makeStore()
        let file = try makeFile("notas.txt")

        store.add([file])

        #expect(store.items.map(\.name) == ["notas.txt"])
        #expect(store.resolvedURL(for: store.items[0])?.standardizedFileURL == file.standardizedFileURL)
        #expect(!FileManager.default.fileExists(atPath: storage.appendingPathComponent("copies").path))
    }

    @Test func theSameFileIsNotAddedTwice() throws {
        let store = makeStore()
        let file = try makeFile("a.txt")

        store.add([file, file])
        store.add([file])

        #expect(store.items.count == 1)
    }

    @Test func limitDropsTheOldestItems() throws {
        let store = makeStore(limit: 2)

        store.add([try makeFile("1.txt"), try makeFile("2.txt"), try makeFile("3.txt")])

        #expect(store.items.map(\.name) == ["2.txt", "3.txt"])
    }

    @Test func itemsSurviveARestartAndFollowMovedFiles() throws {
        let store = makeStore()
        let file = try makeFile("viaje.txt")
        store.add([file])
        let moved = files.appendingPathComponent("movido.txt")
        try FileManager.default.moveItem(at: file, to: moved)

        let reloaded = makeStore()

        #expect(reloaded.items.count == 1)
        #expect(reloaded.resolvedURL(for: reloaded.items[0])?.lastPathComponent == "movido.txt")
    }

    @Test func trashedOriginalsAreCopiedSoTheyKeepWorking() throws {
        let store = makeStore()
        let file = try makeFile("borrador.txt", contents: "importante")
        store.add([file])
        let trash = root.appendingPathComponent(".Trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: file, to: trash.appendingPathComponent("borrador.txt"))

        store.refresh()

        let url = try #require(store.resolvedURL(for: store.items[0]))
        #expect(url.path.hasPrefix(storage.path))
        #expect(try String(contentsOf: url, encoding: .utf8) == "importante")
    }

    @Test func deletedOriginalsDisappearFromTheShelf() throws {
        let store = makeStore()
        let file = try makeFile("efimero.txt")
        store.add([file])
        try FileManager.default.removeItem(at: file)

        store.refresh()

        #expect(store.items.isEmpty)
    }

    @Test func removeAndClear() throws {
        let store = makeStore()
        store.add([try makeFile("x.txt"), try makeFile("y.txt")])

        store.remove(store.items[0].id)
        #expect(store.items.map(\.name) == ["y.txt"])

        store.clear()
        #expect(store.items.isEmpty)
        #expect(makeStore().items.isEmpty)
    }

    @Test func loweringTheLimitTrimsExistingItems() throws {
        let store = makeStore(limit: 3)
        store.add([try makeFile("1.txt"), try makeFile("2.txt"), try makeFile("3.txt")])

        store.setLimit(1)

        #expect(store.items.map(\.name) == ["3.txt"])
    }
}
