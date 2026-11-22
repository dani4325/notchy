import Foundation
import ImageIO
import Observation
import os
import Vision

@MainActor
@Observable
public final class ArtworkBackdrop {
    public struct Prepared: Equatable, Sendable {
        public let url: URL
        public let palette: ThemePalette
        let measurement: BackgroundMeasurement
        public let crop: MediaCrop
    }

    public private(set) var prepared: Prepared?

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private var generation = 0

    private nonisolated static let logger = Logger(subsystem: "com.danirubio.notchy", category: "artwork")
    private nonisolated static let paletteClusters = 6

    public static var defaultDirectory: URL {
        URL.cachesDirectory
            .appendingPathComponent("com.danirubio.notchy", isDirectory: true)
            .appendingPathComponent("Artwork", isDirectory: true)
    }

    public init(directory: URL = ArtworkBackdrop.defaultDirectory) {
        self.directory = directory
    }

    public func prepare(artwork: Data?) async {
        generation += 1
        let request = generation
        let previous = prepared?.url
        guard let artwork else {
            replace(with: nil, removing: previous)
            return
        }
        let url = directory.appendingPathComponent("artwork-" + UUID().uuidString)
        let result = await Task.detached(priority: .utility) { [directory] in
            Self.analyze(artwork, writingTo: url, in: directory)
        }.value
        guard request == generation else {
            result.map { try? FileManager.default.removeItem(at: $0.url) }
            return
        }
        replace(with: result, removing: previous)
    }

    private func replace(with next: Prepared?, removing old: URL?) {
        prepared = next
        guard let old, old != next?.url else { return }
        do {
            try FileManager.default.removeItem(at: old)
        } catch {
            Self.logger.error("old artwork not removed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated static func analyze(_ data: Data, writingTo url: URL, in directory: URL) -> Prepared? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let sample = BackgroundSample.measuring(image)
        else {
            logger.error("artwork could not be decoded")
            return nil
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("artwork not cached: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        let clusters = PaletteExtractor.clusters(from: image, count: paletteClusters)
        return Prepared(
            url: url,
            palette: PaletteBuilder.palette(from: clusters),
            measurement: BackgroundMeasurement(sample: sample, framesChecked: 1, coversEveryFrame: true),
            crop: framing(of: image)
        )
    }

    private nonisolated static func framing(of image: CGImage) -> MediaCrop {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            logger.error("saliency failed: \(error.localizedDescription, privacy: .public)")
            return .standard
        }
        guard let area = request.results?.first?.salientObjects?.max(by: { $0.confidence < $1.confidence })?.boundingBox else {
            return .standard
        }
        return MediaCrop(zoom: 1, focusX: area.midX, focusY: 1 - area.midY).sanitized()
    }
}
