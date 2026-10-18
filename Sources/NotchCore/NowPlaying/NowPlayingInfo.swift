import Foundation

public struct NowPlayingInfo: Equatable, Sendable {
    public let title: String
    public let artist: String?
    public let album: String?
    public let duration: TimeInterval?
    public let elapsed: TimeInterval
    public let timestamp: Date
    public let playbackRate: Double
    public let isPlaying: Bool
    public let appBundleID: String
    public let artworkData: Data?

    public func position(at date: Date) -> TimeInterval {
        let rate = playbackRate > 0 ? playbackRate : 1
        let raw = isPlaying ? elapsed + date.timeIntervalSince(timestamp) * rate : elapsed
        let upper = duration ?? .greatestFiniteMagnitude
        return min(max(raw, 0), upper)
    }

    public func progress(at date: Date) -> Double? {
        guard let duration, duration > 0 else { return nil }
        return position(at: date) / duration
    }

    func withPosition(_ position: TimeInterval, at date: Date) -> NowPlayingInfo {
        NowPlayingInfo(
            title: title, artist: artist, album: album, duration: duration,
            elapsed: position, timestamp: date, playbackRate: playbackRate,
            isPlaying: isPlaying, appBundleID: appBundleID, artworkData: artworkData
        )
    }

    func withArtwork(_ data: Data?) -> NowPlayingInfo {
        NowPlayingInfo(
            title: title, artist: artist, album: album, duration: duration,
            elapsed: elapsed, timestamp: timestamp, playbackRate: playbackRate,
            isPlaying: isPlaying, appBundleID: appBundleID, artworkData: data
        )
    }

    var trackKey: String {
        [appBundleID, title, artist ?? "", album ?? ""].joined(separator: "\u{1F}")
    }
}
