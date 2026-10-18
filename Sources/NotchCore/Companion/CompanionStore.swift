import AppKit
import Observation
import os

@MainActor
@Observable
public final class CompanionStore {
    public enum ImportError: Error, Equatable {
        case unreadableImage
        case copyFailed
    }

    public private(set) var image: NSImage?
    public private(set) var fileURL: URL?
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

    public func importMedia(from source: URL) throws {
        guard let loaded = NSImage(contentsOf: source), loaded.isValid else {
            throw ImportError.unreadableImage
        }
        let destination = directory.appendingPathComponent("companion-\(UUID().uuidString).\(source.pathExtension.lowercased())")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            Self.logger.error("copy failed: \(error.localizedDescription, privacy: .public)")
            throw ImportError.copyFailed
        }
        removeStoredFile()
        defaults.set(destination.lastPathComponent, forKey: Self.fileNameKey)
        fileURL = destination
        image = loaded
    }

    public func chooseFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Elige una imagen o un GIF para acompañar al notch"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try importMedia(from: url)
            lastError = nil
        } catch ImportError.unreadableImage {
            lastError = "No se ha podido leer esa imagen."
        } catch {
            lastError = "No se ha podido guardar la imagen."
        }
    }

    public func clear() {
        removeStoredFile()
        defaults.removeObject(forKey: Self.fileNameKey)
        fileURL = nil
        image = nil
        lastError = nil
    }

    private func load() {
        guard let name = defaults.string(forKey: Self.fileNameKey) else { return }
        let url = directory.appendingPathComponent(name)
        guard let loaded = NSImage(contentsOf: url) else {
            Self.logger.error("stored companion missing: \(name, privacy: .public)")
            defaults.removeObject(forKey: Self.fileNameKey)
            return
        }
        fileURL = url
        image = loaded
    }

    private func removeStoredFile() {
        guard let fileURL else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            Self.logger.error("remove failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
