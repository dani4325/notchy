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
        try? FileManager.default.removeItem(at: destination)
        try run(ditto, ["-c", "-k", "--norsrc", "--noextattr", "--noqtn", "--noacl", folder.path, destination.path])
    }

    static func extract(_ archive: URL) throws -> (theme: Theme, folder: URL) {
        let entries = try run(zipinfo, ["-1", archive.path])
            .split(separator: "\n")
            .map(String.init)
        guard entries.count <= maximumEntries else { throw ArchiveError.tooLarge }
        guard entries.allSatisfy(isSafeEntry) else { throw ArchiveError.unsafeContent }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            try run(ditto, ["-x", "-k", "--norsrc", "--noextattr", "--noqtn", archive.path, folder.path])
            try validateContents(of: folder)
            let theme = try decodeTheme(in: folder)
            return (theme, folder)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    private static func validateContents(of folder: URL) throws {
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
