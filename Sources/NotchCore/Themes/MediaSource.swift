import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct MediaSource: Equatable, Sendable {
    public let url: URL
    public let kind: MediaKind
}

extension MediaKind {
    enum DetectionError: Error {
        case unsupported
    }

    static func detect(at url: URL) throws -> MediaKind {
        let type = UTType(filenameExtension: url.pathExtension.lowercased())
        if let type, type.conforms(to: .movie) || type.conforms(to: .video) {
            return .video
        }
        guard let type, type.conforms(to: .image),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0
        else { throw DetectionError.unsupported }
        return CGImageSourceGetCount(source) > 1 ? .animatedImage : .image
    }
}
