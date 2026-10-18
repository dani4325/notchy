import AppKit
import Observation
import os

@MainActor
@Observable
public final class CompanionStore {
    public enum ImportError: Error, Equatable {
        case unsupportedMedia
        case copyFailed
    }

    public private(set) var source: MediaSource?
    public private(set) var lastError: String?

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let defaults: UserDefaults

    private static let fileNameKey = "companionFileName"
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "companion")

    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("Notchy", isDirectory: true)
            .appendingPathComponent("Companion", isDirectory: true)
    }

    public init(directory: URL = CompanionStore.defaultDirectory, defaults: UserDefaults = .standard) {
        self.directory = directory
        self.defaults = defaults
        load()
    }

    public func importMedia(from url: URL) throws {
        let kind: MediaKind
        do {
            kind = try MediaKind.detect(at: url)
        } catch {
            throw ImportError.unsupportedMedia
        }
        let destination = directory.appendingPathComponent("companion-\(UUID().uuidString).\(url.pathExtension.lowercased())")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            Self.logger.error("copy failed: \(error.localizedDescription, privacy: .public)")
            throw ImportError.copyFailed
        }
        removeStoredFile()
        defaults.set(destination.lastPathComponent, forKey: Self.fileNameKey)
        source = MediaSource(url: destination, kind: kind)
    }

    public func chooseFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = false
        panel.message = "Elige una imagen, un GIF o un vídeo para acompañar al notch"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try importMedia(from: url)
            lastError = nil
        } catch ImportError.unsupportedMedia {
            lastError = "Ese archivo no es una imagen ni un vídeo compatible."
        } catch {
            lastError = "No se ha podido guardar el archivo."
        }
    }

    public func clear() {
        removeStoredFile()
        defaults.removeObject(forKey: Self.fileNameKey)
        source = nil
        lastError = nil
    }

    private func load() {
        guard let name = defaults.string(forKey: Self.fileNameKey) else { return }
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path), let kind = try? MediaKind.detect(at: url) else {
            Self.logger.error("stored companion missing: \(name, privacy: .public)")
            defaults.removeObject(forKey: Self.fileNameKey)
            return
        }
        source = MediaSource(url: url, kind: kind)
    }

    private func removeStoredFile() {
        guard let url = source?.url else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Self.logger.error("remove failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
