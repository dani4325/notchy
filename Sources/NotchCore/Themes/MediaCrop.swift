import CoreGraphics

public struct MediaCrop: Codable, Equatable, Sendable {
    public static let zoomRange: ClosedRange<Double> = 1...4
    public static let standard = MediaCrop(zoom: 1, focusX: 0.5, focusY: 0.5)

    public var zoom: Double
    public var focusX: Double
    public var focusY: Double

    public init(zoom: Double, focusX: Double, focusY: Double) {
        self.zoom = zoom
        self.focusX = focusX
        self.focusY = focusY
    }

    private enum CodingKeys: String, CodingKey {
        case zoom, focusX, focusY
        case legacyCenterX = "centerX"
        case legacyCenterY = "centerY"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        zoom = try container.decodeIfPresent(Double.self, forKey: .zoom) ?? 1
        focusX = try container.decodeIfPresent(Double.self, forKey: .focusX)
            ?? container.decodeIfPresent(Double.self, forKey: .legacyCenterX) ?? 0.5
        focusY = try container.decodeIfPresent(Double.self, forKey: .focusY)
            ?? container.decodeIfPresent(Double.self, forKey: .legacyCenterY) ?? 0.5
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(zoom, forKey: .zoom)
        try container.encode(focusX, forKey: .focusX)
        try container.encode(focusY, forKey: .focusY)
    }

    public func sanitized() -> MediaCrop {
        MediaCrop(
            zoom: zoom.clamped(to: Self.zoomRange),
            focusX: focusX.clamped(to: 0...1),
            focusY: focusY.clamped(to: 0...1)
        )
    }

    public func rect(mediaAspect: Double, targetAspect: Double) -> CGRect {
        guard mediaAspect > 0, targetAspect > 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        let safe = sanitized()
        let baseWidth = mediaAspect > targetAspect ? targetAspect / mediaAspect : 1
        let baseHeight = mediaAspect > targetAspect ? 1 : mediaAspect / targetAspect
        let width = baseWidth / safe.zoom
        let height = baseHeight / safe.zoom
        return CGRect(
            x: (safe.focusX - width / 2).clamped(to: 0...(1 - width)),
            y: (safe.focusY - height / 2).clamped(to: 0...(1 - height)),
            width: width,
            height: height
        )
    }

    public func dragged(by translation: CGSize, displayedSize: CGSize, mediaAspect: Double) -> MediaCrop {
        guard displayedSize.width > 0, displayedSize.height > 0 else { return self }
        let targetAspect = displayedSize.width / displayedSize.height
        let window = rect(mediaAspect: mediaAspect, targetAspect: targetAspect)
        let moved = MediaCrop(
            zoom: zoom,
            focusX: window.midX - translation.width / displayedSize.width * window.width,
            focusY: window.midY - translation.height / displayedSize.height * window.height
        )
        let reachable = moved.rect(mediaAspect: mediaAspect, targetAspect: targetAspect)
        return MediaCrop(zoom: zoom, focusX: reachable.midX, focusY: reachable.midY).sanitized()
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
