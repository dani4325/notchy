import AppKit
import Observation
import os

@MainActor
@Observable
public final class ThemeStore {
    public enum StoreError: Error, Equatable {
        case unknownTheme
        case lastTheme
        case unsupportedMedia
        case mediaTooLarge
        case writeFailed
        case builtInTheme
    }

    nonisolated static let themeFileName = "theme.json"
    nonisolated static let mediaFolderName = "media"
    static let maximumMediaBytes = 200 * 1024 * 1024
    private static let activeKey = "activeThemeID"
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "themes")

    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("Notchy", isDirectory: true)
            .appendingPathComponent("Themes", isDirectory: true)
    }

    public private(set) var themes: [Theme] = []
    public private(set) var activeThemeID: String

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let defaults: UserDefaults

    public init(directory: URL = ThemeStore.defaultDirectory, defaults: UserDefaults = .standard) {
        self.directory = directory
        self.defaults = defaults
        activeThemeID = defaults.string(forKey: Self.activeKey) ?? Theme.notchyDefault.id
        reload()
    }

    public var activeTheme: Theme {
        themes.first { $0.id == activeThemeID } ?? themes.first ?? Theme.notchyDefault
    }

    public func isBuiltIn(_ themeID: String) -> Bool {
        Theme.builtIns.contains { $0.id == themeID }
    }

    public func theme(id: String) -> Theme? {
        themes.first { $0.id == id }
    }

    public func folder(for themeID: String) -> URL {
        directory.appendingPathComponent(themeID, isDirectory: true)
    }

    public func mediaURL(themeID: String, media: ThemeMedia) -> URL {
        folder(for: themeID).appendingPathComponent(Self.mediaFolderName).appendingPathComponent(media.file)
    }

    public func activate(themeID: String) {
        guard theme(id: themeID) != nil else { return }
        activeThemeID = themeID
        defaults.set(themeID, forKey: Self.activeKey)
    }

    public func save(_ theme: Theme) throws {
        guard !isBuiltIn(theme.id) else { throw StoreError.builtInTheme }
        let clean = theme.sanitized()
        try write(clean)
        themes = sorted(themes.filter { $0.id != clean.id } + [clean])
    }

    public func createTheme(named name: String) throws -> Theme {
        var theme = Theme.notchyDefault
        theme.id = Self.newID()
        theme.name = name
        try save(theme)
        return theme
    }

    public func duplicate(themeID: String) throws -> Theme {
        guard let original = theme(id: themeID) else { throw StoreError.unknownTheme }
        var copy = original
        copy.id = Self.newID()
        copy.name = String("\(original.name) (copia)".prefix(40))
        if FileManager.default.fileExists(atPath: folder(for: original.id).path) {
            try copyFolder(from: folder(for: original.id), to: folder(for: copy.id))
        }
        try save(copy)
        return copy
    }

    public func delete(themeID: String) throws {
        guard theme(id: themeID) != nil else { throw StoreError.unknownTheme }
        guard !isBuiltIn(themeID) else { throw StoreError.builtInTheme }
        guard themes.filter({ !isBuiltIn($0.id) }).count > 1 else { throw StoreError.lastTheme }
        try? FileManager.default.removeItem(at: folder(for: themeID))
        themes = themes.filter { $0.id != themeID }
        if activeThemeID == themeID, let first = themes.first {
            activate(themeID: first.id)
        }
    }

    public func setBackground(from source: URL, themeID: String) throws -> Theme {
        guard var theme = theme(id: themeID) else { throw StoreError.unknownTheme }
        guard !isBuiltIn(themeID) else { throw StoreError.builtInTheme }
        let kind: MediaKind
        do {
            kind = try MediaKind.detect(at: source)
        } catch {
            throw StoreError.unsupportedMedia
        }
        let size = (try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= Self.maximumMediaBytes else { throw StoreError.mediaTooLarge }

        let name = "background-\(UUID().uuidString.prefix(8)).\(source.pathExtension.lowercased())"
        let mediaFolder = folder(for: themeID).appendingPathComponent(Self.mediaFolderName)
        do {
            try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: mediaFolder.appendingPathComponent(name))
        } catch {
            Self.logger.error("media copy failed: \(error.localizedDescription, privacy: .public)")
            throw StoreError.writeFailed
        }

        let previous = theme.background?.media
        theme.background = ThemeBackground(
            media: ThemeMedia(kind: kind, file: name, crop: .standard),
            legibility: theme.background?.legibility ?? ThemeBackground.defaultLegibility
        )
        try save(theme)
        if let previous {
            try? FileManager.default.removeItem(at: mediaURL(themeID: themeID, media: previous))
        }
        return theme
    }

    public func clearBackground(themeID: String) throws -> Theme {
        guard var theme = theme(id: themeID) else { throw StoreError.unknownTheme }
        guard !isBuiltIn(themeID) else { throw StoreError.builtInTheme }
        let previous = theme.background?.media
        theme.background = nil
        try save(theme)
        if let previous {
            try? FileManager.default.removeItem(at: mediaURL(themeID: themeID, media: previous))
        }
        return theme
    }

    public func exportArchive(themeID: String, to destination: URL) throws {
        guard let theme = theme(id: themeID) else { throw StoreError.unknownTheme }
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-export-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }

        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Self.encoder.encode(theme).write(to: staging.appendingPathComponent(Self.themeFileName))
        if let media = theme.background?.media {
            let mediaFolder = staging.appendingPathComponent(Self.mediaFolderName)
            try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(
                at: mediaURL(themeID: themeID, media: media),
                to: mediaFolder.appendingPathComponent(media.file)
            )
        }
        try ThemeArchive.compress(folder: staging, to: destination)
    }

    public func importArchive(from archive: URL) throws -> Theme {
        let (extracted, folder) = try ThemeArchive.extract(archive)
        defer { try? FileManager.default.removeItem(at: folder) }

        var theme = extracted
        theme.id = Self.newID()
        try copyFolder(from: folder, to: self.folder(for: theme.id))
        try save(theme)
        return theme
    }

    private func reload() {
        let loaded = loadAll()
        if loaded.isEmpty {
            do {
                try write(Theme.notchyDefault)
            } catch {
                Self.logger.error("seeding default theme failed")
            }
            themes = sorted([Theme.notchyDefault] + Theme.builtIns)
        } else {
            themes = sorted(loaded.filter { !isBuiltIn($0.id) } + Theme.builtIns)
        }
        if theme(id: activeThemeID) == nil, let first = themes.first {
            activeThemeID = first.id
        }
    }

    private func loadAll() -> [Theme] {
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )) ?? []
        return folders.compactMap { folder in
            let file = folder.appendingPathComponent(Self.themeFileName)
            guard let data = try? Data(contentsOf: file) else { return nil }
            do {
                var theme = try JSONDecoder().decode(Theme.self, from: data).sanitized()
                theme.id = folder.lastPathComponent
                return theme
            } catch {
                Self.logger.error("skipping invalid theme at \(folder.lastPathComponent, privacy: .public)")
                return nil
            }
        }
    }

    private func write(_ theme: Theme) throws {
        let themeFolder = folder(for: theme.id)
        do {
            try FileManager.default.createDirectory(at: themeFolder, withIntermediateDirectories: true)
            try Self.encoder.encode(theme).write(to: themeFolder.appendingPathComponent(Self.themeFileName), options: .atomic)
        } catch {
            Self.logger.error("theme write failed: \(error.localizedDescription, privacy: .public)")
            throw StoreError.writeFailed
        }
    }

    private func copyFolder(from source: URL, to destination: URL) throws {
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            Self.logger.error("folder copy failed: \(error.localizedDescription, privacy: .public)")
            throw StoreError.writeFailed
        }
    }

    private func sorted(_ list: [Theme]) -> [Theme] {
        list.sorted { lhs, rhs in
            let left = (rank(lhs), lhs.name.lowercased())
            let right = (rank(rhs), rhs.name.lowercased())
            return left < right
        }
    }

    private func rank(_ theme: Theme) -> Int {
        if theme.id == Theme.notchyDefault.id { return 0 }
        return isBuiltIn(theme.id) ? 1 : 2
    }

    private static func newID() -> String {
        UUID().uuidString.lowercased()
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
