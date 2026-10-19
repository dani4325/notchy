import Foundation
import os

extension ThemeStore {
    nonisolated static let measurementSuffix = ".legibility.json"
    private static let legibilityLogger = Logger(subsystem: "com.danirubio.notchy", category: "legibility")

    func measurementURL(themeID: String, media: ThemeMedia) -> URL {
        let mediaFile = mediaURL(themeID: themeID, media: media)
        return mediaFile.deletingLastPathComponent().appendingPathComponent(media.file + Self.measurementSuffix)
    }

    func measurement(themeID: String) -> BackgroundMeasurement? {
        measurements[themeID]
    }

    func saveMeasurement(_ measurement: BackgroundMeasurement, themeID: String, media: ThemeMedia) {
        do {
            try JSONEncoder().encode(measurement).write(to: measurementURL(themeID: themeID, media: media), options: .atomic)
            setMeasurement(measurement, themeID: themeID)
        } catch {
            Self.legibilityLogger.error("saving measurement failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func measureMissing() async {
        for theme in themes where measurements[theme.id] == nil && !isBuiltIn(theme.id) {
            guard let media = theme.background?.media else { continue }
            let url = mediaURL(themeID: theme.id, media: media)
            guard let measurement = await BackgroundMeasurer.measureInBackground(url, kind: media.kind) else {
                Self.legibilityLogger.error("could not measure background of \(theme.id, privacy: .public)")
                continue
            }
            guard self.theme(id: theme.id)?.background?.media == media else { continue }
            saveMeasurement(measurement, themeID: theme.id, media: media)
        }
    }

    func removeMedia(_ media: ThemeMedia, themeID: String) {
        for url in [mediaURL(themeID: themeID, media: media), measurementURL(themeID: themeID, media: media)] {
            do {
                try FileManager.default.removeItem(at: url)
            } catch CocoaError.fileNoSuchFile {
                continue
            } catch {
                Self.legibilityLogger.error("removing old background failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        setMeasurement(nil, themeID: themeID)
    }

    func loadMeasurements() -> [String: BackgroundMeasurement] {
        var loaded: [String: BackgroundMeasurement] = [:]
        for theme in themes {
            guard let media = theme.background?.media,
                  let data = try? Data(contentsOf: measurementURL(themeID: theme.id, media: media))
            else { continue }
            do {
                loaded[theme.id] = try JSONDecoder().decode(BackgroundMeasurement.self, from: data)
            } catch {
                Self.legibilityLogger.error("ignoring unreadable measurement for \(theme.id, privacy: .public)")
            }
        }
        return loaded
    }

    nonisolated static func discardMeasurements(in folder: URL) {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        for file in files where file.lastPathComponent.hasSuffix(measurementSuffix) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
