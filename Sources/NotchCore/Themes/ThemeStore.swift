import AppKit
import Observation
import os

@MainActor
@Observable
public final class ThemeStore {
    public enum StoreError: Error, Equatable {
        case unknownTheme
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
    public private(set) var overrideThemeID: String?
    private(set) var measurements: [String: BackgroundMeasurement] = [:]
    public private(set) var unreadableThemes = 0

    func setMeasurement(_ measurement: BackgroundMeasurement?, themeID: String) {
        measurements[themeID] = measurement
    }

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let trash: @MainActor (URL) throws -> URL
    @ObservationIgnored public let artworkBackdrop: ArtworkBackdrop

    public init(directory: URL = ThemeStore.defaultDirectory, defaults: UserDefaults = .standard, trash: @escaping @MainActor (URL) throws -> URL = ThemeStore.moveToTrash) {
        self.directory = directory
        self.defaults = defaults
        self.trash = trash
        artworkBackdrop = ArtworkBackdrop()
        activeThemeID = defaults.string(forKey: Self.activeKey) ?? Theme.notchyDefault.id
        reload()
        migrateLegacyThemes()
    }

    public var activeTheme: Theme {
        if let overrideThemeID, let shown = theme(id: overrideThemeID) {
            return shown
        }
        return themes.first { $0.id == activeThemeID } ?? themes.first ?? Theme.notchyDefault
    }

    public func setOverride(themeID: String?) {
        guard overrideThemeID != themeID else { return }
        overrideThemeID = themeID
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
        copy.name = String(String(localized: "\(original.name) (copia)").prefix(40))
        if FileManager.default.fileExists(atPath: folder(for: original.id).path) {
            try copyFolder(from: folder(for: original.id), to: folder(for: copy.id))
        }
        try save(copy)
        setMeasurement(measurements[original.id], themeID: copy.id)
        return copy
    }

    public static func moveToTrash(_ url: URL) throws -> URL {
        var trashed: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &trashed)
        guard let trashed else { throw StoreError.writeFailed }
        return trashed as URL
    }

    @discardableResult
    public func delete(themeID: String) throws -> URL {
        guard theme(id: themeID) != nil else { throw StoreError.unknownTheme }
        guard !isBuiltIn(themeID) else { throw StoreError.builtInTheme }
        let trashed: URL
        do {
            trashed = try trash(folder(for: themeID))
        } catch {
            Self.logger.error("moving theme to the Trash failed: \(error.localizedDescription, privacy: .public)")
            throw StoreError.writeFailed
        }
        themes = themes.filter { $0.id != themeID }
        setMeasurement(nil, themeID: themeID)
        if activeThemeID == themeID, let first = themes.first {
            activate(themeID: first.id)
        }
        return trashed
    }

    public func restore(themeID: String, from trashed: URL) throws {
        do {
            try FileManager.default.moveItem(at: trashed, to: folder(for: themeID))
        } catch {
            Self.logger.error("restoring theme from the Trash failed: \(error.localizedDescription, privacy: .public)")
            throw StoreError.writeFailed
        }
        reload()
    }

    func setBackground(from source: URL, themeID: String, measurement: BackgroundMeasurement) throws -> Theme {
        let theme = try setBackground(from: source, themeID: themeID)
        if let media = theme.background?.media {
            saveMeasurement(measurement, themeID: themeID, media: media)
        }
        return theme
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
            removeMedia(previous, themeID: themeID)
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
            removeMedia(previous, themeID: themeID)
        }
        return theme
    }

    public func exportArchive(themeID: String, to destination: URL) throws {
        let (theme, media) = try exportPayload(themeID: themeID)
        try Self.writeArchive(theme: theme, mediaURL: media, to: destination)
    }

    func exportPayload(themeID: String) throws -> (Theme, URL?) {
        guard let theme = theme(id: themeID) else { throw StoreError.unknownTheme }
        return (theme, theme.background.map { mediaURL(themeID: themeID, media: $0.media) })
    }

    nonisolated static func writeArchive(theme: Theme, mediaURL: URL?, to destination: URL) throws {
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-export-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }

        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(theme).write(to: staging.appendingPathComponent(themeFileName))
        if let mediaURL, let media = theme.background?.media {
            let mediaFolder = staging.appendingPathComponent(mediaFolderName)
            try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: mediaURL, to: mediaFolder.appendingPathComponent(media.file))
        }
        try ThemeArchive.compress(folder: staging, to: destination)
    }

    public func importArchive(from archive: URL) throws -> Theme {
        let id = Self.newID()
        let staged = try Self.stageImport(archive: archive, into: folder(for: id))
        return try finishImport(staged, id: id)
    }

    func importDestination() -> (id: String, folder: URL) {
        let id = Self.newID()
        return (id, folder(for: id))
    }

    nonisolated static func stageImport(archive: URL, into destination: URL) throws -> Theme {
        let (extracted, folder) = try ThemeArchive.extract(archive)
        defer { try? FileManager.default.removeItem(at: folder) }
        discardMeasurements(in: folder)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: folder, to: destination)
        return extracted
    }

    func finishImport(_ extracted: Theme, id: String) throws -> Theme {
        var theme = extracted
        theme.id = id
        do {
            try save(theme)
        } catch {
            try? FileManager.default.removeItem(at: folder(for: id))
            throw error
        }
        return theme
    }

    private func reload() {
        themes = sorted(loadAll().filter { !isBuiltIn($0.id) } + Theme.builtIns)
        if theme(id: activeThemeID) == nil, let first = themes.first {
            activeThemeID = first.id
        }
        measurements = loadMeasurements()
    }

    private func loadAll() -> [Theme] {
        var unreadable = 0
        defer { unreadableThemes = unreadable }
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
                unreadable += 1
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

    private func migrateLegacyThemes() {
        var replacements: [String: String] = [:]
        if let seed = theme(id: LegacyTemplates.legacyDefaultID), isUneditedSeed(seed) {
            do {
                _ = try trash(folder(for: seed.id))
                themes = themes.filter { $0.id != seed.id }
                replacements[seed.id] = Theme.notchyDefault.id
            } catch {
                Self.logger.error("removing the unedited default theme failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        let storedActive = defaults.string(forKey: Self.activeKey)
        let rules = defaults.data(forKey: AutoThemeController.rulesKey).flatMap { try? JSONDecoder().decode(AutoThemeRules.self, from: $0) }
        let referenced = [storedActive].compactMap { $0 } + (rules.map { $0.schedule.map(\.themeID) + $0.apps.map(\.themeID) } ?? [])
        for legacyID in Set(referenced) where LegacyTemplates.isLegacy(legacyID) && replacements[legacyID] == nil {
            var migrated = LegacyTemplates.theme(forLegacyID: legacyID)
            migrated.id = Self.newID()
            migrated.name = uniqueName(LegacyTemplates.migratedName)
            do {
                try save(migrated)
                replacements[legacyID] = migrated.id
            } catch {
                Self.logger.error("migrating a 1.0 template failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        guard !replacements.isEmpty else { return }

        if let storedActive, let replacement = replacements[storedActive] {
            activate(themeID: replacement)
        }
        if var updated = rules {
            for index in updated.schedule.indices { updated.schedule[index].themeID = replacements[updated.schedule[index].themeID] ?? updated.schedule[index].themeID }
            for index in updated.apps.indices { updated.apps[index].themeID = replacements[updated.apps[index].themeID] ?? updated.apps[index].themeID }
            do {
                defaults.set(try JSONEncoder().encode(updated), forKey: AutoThemeController.rulesKey)
            } catch {
                Self.logger.error("rewriting rules after migration failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func isUneditedSeed(_ theme: Theme) -> Bool {
        var probe = theme
        probe.id = Theme.notchyDefault.id
        return probe == Theme.notchyDefault && !FileManager.default.fileExists(atPath: folder(for: theme.id).appendingPathComponent(Self.mediaFolderName).path)
    }

    private func uniqueName(_ base: String) -> String {
        let taken = Set(themes.map(\.name))
        guard taken.contains(base) else { return base }
        return (2...).lazy.map { base + " " + String($0) }.first { !taken.contains($0) } ?? base
    }

    nonisolated static func newID() -> String {
        UUID().uuidString.lowercased()
    }

    private nonisolated static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
