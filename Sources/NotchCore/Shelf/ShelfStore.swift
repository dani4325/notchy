import Foundation
import Observation
import os

public struct ShelfItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    var bookmark: Data
    var copyFileName: String?
}

@MainActor
@Observable
public final class ShelfStore {
    public nonisolated static let limitRange = 1...50
    public nonisolated static let defaultLimit = 10

    public private(set) var items: [ShelfItem] = []
    public private(set) var limit: Int

    @ObservationIgnored private let directory: URL
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "shelf")

    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Notchy/Shelf", isDirectory: true)
    }

    private var indexURL: URL { directory.appendingPathComponent("shelf.json") }
    private var copiesDirectory: URL { directory.appendingPathComponent("copies", isDirectory: true) }

    public init(directory: URL = ShelfStore.defaultDirectory, limit: Int = ShelfStore.defaultLimit) {
        self.directory = directory
        self.limit = limit.clamped(to: Self.limitRange)
        load()
        refresh()
    }

    public func add(_ urls: [URL]) {
        var updated = items
        for url in urls where url.isFileURL {
            let standardized = url.standardizedFileURL
            guard !updated.contains(where: { resolvedURL(for: $0)?.standardizedFileURL == standardized }) else { continue }
            do {
                let bookmark = try standardized.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                updated.append(ShelfItem(id: UUID(), name: standardized.lastPathComponent, bookmark: bookmark, copyFileName: nil))
            } catch {
                Self.logger.error("bookmark failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        commit(trimmed(updated))
    }

    public func remove(_ id: UUID) {
        let removed = items.filter { $0.id == id }
        removed.forEach(deleteCopy)
        commit(items.filter { $0.id != id })
    }

    public func clear() {
        items.forEach(deleteCopy)
        commit([])
    }

    public func setLimit(_ newLimit: Int) {
        limit = newLimit.clamped(to: Self.limitRange)
        commit(trimmed(items))
    }

    public func resolvedURL(for item: ShelfItem) -> URL? {
        if let copy = item.copyFileName {
            let url = copiesDirectory.appendingPathComponent(copy)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: item.bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }

    public func refresh() {
        let updated = items.compactMap { item -> ShelfItem? in
            guard let url = resolvedURL(for: item) else { return nil }
            guard item.copyFileName == nil, Self.isInTrash(url) else { return item }
            return preserveCopy(of: item, from: url)
        }
        commit(updated)
    }

    static func isInTrash(_ url: URL) -> Bool {
        url.pathComponents.contains(".Trash")
    }

    private func preserveCopy(of item: ShelfItem, from url: URL) -> ShelfItem? {
        let name = "\(item.id.uuidString)-\(url.lastPathComponent)"
        do {
            try FileManager.default.createDirectory(at: copiesDirectory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: copiesDirectory.appendingPathComponent(name))
            var copy = item
            copy.copyFileName = name
            return copy
        } catch {
            Self.logger.error("copy of trashed item failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func trimmed(_ list: [ShelfItem]) -> [ShelfItem] {
        guard list.count > limit else { return list }
        let dropped = list.prefix(list.count - limit)
        dropped.forEach(deleteCopy)
        return Array(list.suffix(limit))
    }

    private func deleteCopy(_ item: ShelfItem) {
        guard let copy = item.copyFileName else { return }
        try? FileManager.default.removeItem(at: copiesDirectory.appendingPathComponent(copy))
    }

    private func commit(_ updated: [ShelfItem]) {
        guard updated != items else { return }
        items = updated
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: indexURL, options: .atomic)
        } catch {
            Self.logger.error("shelf save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        do {
            items = Array(try JSONDecoder().decode([ShelfItem].self, from: data).suffix(limit))
        } catch {
            Self.logger.error("shelf index unreadable: \(error.localizedDescription, privacy: .public)")
        }
    }
}
