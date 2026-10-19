import Foundation
import os

extension ThemeStore {
    enum GIFMigrationError: Error {
        case mismatch
        case measurementFailed
        case themeChanged
    }

    private static let migrationLogger = Logger(subsystem: "com.danirubio.notchy", category: "migration")

    public func migrateGIFBackgrounds() async {
        for theme in themes where !isBuiltIn(theme.id) {
            guard let background = theme.background, background.media.kind == .animatedImage else { continue }
            do {
                try await migrateGIF(of: theme.id, background: background)
            } catch {
                Self.migrationLogger.error("keeping GIF of \(theme.id, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func migrateGIF(of themeID: String, background: ThemeBackground) async throws {
        let gif = mediaURL(themeID: themeID, media: background.media)
        let video = try await GIFTranscoder.transcode(gif)
        defer { try? FileManager.default.removeItem(at: video) }
        guard await GIFTranscoder.matches(video: video, gif: gif) else { throw GIFMigrationError.mismatch }
        guard let measurement = await BackgroundMeasurer.measureInBackground(video, kind: .video) else {
            throw GIFMigrationError.measurementFailed
        }
        guard var updated = theme(id: themeID), updated.background?.media == background.media else {
            throw GIFMigrationError.themeChanged
        }

        let media = ThemeMedia(kind: .video, file: "background-\(UUID().uuidString.prefix(8)).\(video.pathExtension)", crop: background.media.crop)
        let destination = mediaURL(themeID: themeID, media: media)
        try FileManager.default.copyItem(at: video, to: destination)
        updated.background?.media = media
        do {
            try save(updated)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        saveMeasurement(measurement, themeID: themeID, media: media)
        try? FileManager.default.removeItem(at: measurementURL(themeID: themeID, media: background.media))
        _ = try trash(gif)
    }
}
