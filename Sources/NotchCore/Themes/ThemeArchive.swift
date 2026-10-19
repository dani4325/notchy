import Foundation
import os

enum ThemeArchive {
    enum ArchiveError: Error, Equatable {
        case toolFailed
        case unsafeContent
        case missingThemeFile
        case invalidTheme
        case tooLarge
    }

    static let fileExtension = "notchytheme"
    static let maximumEntries = 64
    static let maximumBytes = 300 * 1024 * 1024

    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "archive")
    private static let ditto = URL(fileURLWithPath: "/usr/bin/ditto")
    private static let zipinfo = URL(fileURLWithPath: "/usr/bin/zipinfo")

    static func isSafeEntry(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("/"), !name.contains("\\") else { return false }
        return !name.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    static func compress(folder: URL, to destination: URL) throws {
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-export-\(UUID().uuidString).zip")
        try run(ditto, ["-c", "-k", "--norsrc", "--noextattr", "--noqtn", "--noacl", folder.path, staging.path])
        do {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: staging)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            logger.error("export move failed: \(error.localizedDescription, privacy: .public)")
            throw ArchiveError.toolFailed
        }
    }

    static func preflight(listing: String, maximumBytes: Int, maximumEntries: Int) throws -> [String] {
        var names: [String] = []
        var total = 0
        for line in listing.split(separator: "\n") {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 9, let mode = fields.first, mode.count == 10, "-dl".contains(mode.first!) else { continue }
            guard mode.first != "l" else { throw ArchiveError.unsafeContent }
            guard let size = Int(fields[3]) else { throw ArchiveError.unsafeContent }
            let prefix = line.ranges(of: fields[7]).last.map { line[$0.upperBound...] } ?? ""
            let name = prefix.drop { $0 == " " }
            guard isSafeEntry(String(name)) else { throw ArchiveError.unsafeContent }
            total += size
            names.append(String(name))
            if total > maximumBytes || names.count > maximumEntries { throw ArchiveError.tooLarge }
        }
        return names
    }

    static func listing(of archive: URL) throws -> String {
        try run(zipinfo, [archive.path])
    }

    static func extract(
        _ archive: URL,
        maximumBytes: Int = maximumBytes,
        workingDirectory: URL = FileManager.default.temporaryDirectory
    ) throws -> (theme: Theme, folder: URL) {
        _ = try preflight(listing: listing(of: archive), maximumBytes: maximumBytes, maximumEntries: maximumEntries)

        let folder = workingDirectory.appendingPathComponent("notchy-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            var extractor = try ZipExtractor(archive: archive, maximumBytes: maximumBytes, maximumEntries: maximumEntries)
            try extractor.extract(into: folder)
            try validateContents(of: folder, maximumBytes: maximumBytes)
            let theme = try decodeTheme(in: folder)
            return (theme, folder)
        } catch let error as ArchiveError {
            try? FileManager.default.removeItem(at: folder)
            throw error
        } catch {
            try? FileManager.default.removeItem(at: folder)
            logger.error("extraction failed: \(error.localizedDescription, privacy: .public)")
            throw ArchiveError.unsafeContent
        }
    }

    private static func validateContents(of folder: URL, maximumBytes: Int) throws {
        let keys: [URLResourceKey] = [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys) else {
            throw ArchiveError.unsafeContent
        }
        var total = 0
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true { throw ArchiveError.unsafeContent }
            guard values.isRegularFile == true || values.isDirectory == true else { throw ArchiveError.unsafeContent }
            total += values.fileSize ?? 0
            if total > maximumBytes { throw ArchiveError.tooLarge }
        }
    }

    private static func decodeTheme(in folder: URL) throws -> Theme {
        let themeFile = folder.appendingPathComponent(ThemeStore.themeFileName)
        guard FileManager.default.fileExists(atPath: themeFile.path) else { throw ArchiveError.missingThemeFile }
        do {
            let theme = try JSONDecoder().decode(Theme.self, from: Data(contentsOf: themeFile)).sanitized()
            if let media = theme.background?.media {
                let file = folder.appendingPathComponent(ThemeStore.mediaFolderName).appendingPathComponent(media.file)
                guard FileManager.default.fileExists(atPath: file.path) else { throw ArchiveError.invalidTheme }
            }
            return theme
        } catch let error as ArchiveError {
            throw error
        } catch {
            logger.error("invalid theme.json: \(error.localizedDescription, privacy: .public)")
            throw ArchiveError.invalidTheme
        }
    }

    @discardableResult
    private static func run(_ tool: URL, _ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = tool
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            logger.error("\(tool.lastPathComponent, privacy: .public) launch failed: \(error.localizedDescription, privacy: .public)")
            throw ArchiveError.toolFailed
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            logger.error("\(tool.lastPathComponent, privacy: .public) exited \(process.terminationStatus)")
            throw ArchiveError.toolFailed
        }
        return String(decoding: data, as: UTF8.self)
    }
}
