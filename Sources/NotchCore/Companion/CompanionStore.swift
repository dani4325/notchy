import AppKit
import Observation
import os

@MainActor
@Observable
public final class CompanionStore {
    public enum ImportError: Error, Equatable {
        case unsupportedMedia
        case tooLarge
        case copyFailed
    }

    static let maximumBytes = 200 * 1024 * 1024

    public private(set) var source: MediaSource?
    public private(set) var lastError: String?

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let trash: @MainActor (URL) throws -> URL

    private static let fileNameKey = "companionFileName"
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "companion")

    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("Notchy", isDirectory: true)
            .appendingPathComponent("Companion", isDirectory: true)
    }

    public init(directory: URL = CompanionStore.defaultDirectory, defaults: UserDefaults = .standard, trash: @escaping @MainActor (URL) throws -> URL = ThemeStore.moveToTrash) {
        self.trash = trash
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
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= Self.maximumBytes else { throw ImportError.tooLarge }
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

    public func migrateGIF() async {
        guard let source, source.kind == .animatedImage else { return }
        do {
            let video = try await GIFTranscoder.transcode(source.url)
            defer { try? FileManager.default.removeItem(at: video) }
            guard await GIFTranscoder.matches(video: video, gif: source.url) else { throw GIFTranscoder.TranscodeError.encodingFailed }
            guard self.source == source else { return }
            let destination = directory.appendingPathComponent("companion-\(UUID().uuidString).\(video.pathExtension)")
            try FileManager.default.copyItem(at: video, to: destination)
            defaults.set(destination.lastPathComponent, forKey: Self.fileNameKey)
            self.source = MediaSource(url: destination, kind: .video)
            _ = try trash(source.url)
        } catch {
            Self.logger.error("keeping companion GIF: \(String(describing: error), privacy: .public)")
        }
    }

    public func chooseFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Elige una imagen, un GIF o un vídeo para acompañar al notch")
        panel.begin { [weak self] response in
            MainActor.assumeIsolated {
                guard response == .OK, let url = panel.url, let self else { return }
                Task { await self.importConvertingGIFs(from: url) }
            }
        }
    }

    func importConvertingGIFs(from url: URL) async {
        do {
            if (try? MediaKind.detect(at: url)) == .animatedImage {
                let video = try await GIFTranscoder.transcode(url)
                defer { try? FileManager.default.removeItem(at: video) }
                try importMedia(from: video)
            } else {
                try importMedia(from: url)
            }
            lastError = nil
        } catch GIFTranscoder.TranscodeError.unreadable {
            lastError = String(localized: "Ese archivo no es una imagen ni un vídeo compatible.")
        } catch GIFTranscoder.TranscodeError.encodingFailed {
            lastError = String(localized: "No se ha podido convertir el GIF a vídeo.")
        } catch ImportError.unsupportedMedia {
            lastError = String(localized: "Ese archivo no es una imagen ni un vídeo compatible.")
        } catch ImportError.tooLarge {
            lastError = String(localized: "El archivo supera los 200 MB.")
        } catch {
            lastError = String(localized: "No se ha podido guardar el archivo.")
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
