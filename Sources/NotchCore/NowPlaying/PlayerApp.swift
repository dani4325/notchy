import Foundation

enum PlayerApp: CaseIterable, Sendable {
    case spotify
    case music

    var bundleID: String {
        switch self {
        case .spotify: "com.spotify.client"
        case .music: "com.apple.Music"
        }
    }

    var scriptName: String {
        switch self {
        case .spotify: "Spotify"
        case .music: "Music"
        }
    }

    var notificationName: Notification.Name {
        switch self {
        case .spotify: Notification.Name("com.spotify.client.PlaybackStateChanged")
        case .music: Notification.Name("com.apple.Music.playerInfo")
        }
    }

    private var durationKey: String {
        switch self {
        case .spotify: "Duration"
        case .music: "Total Time"
        }
    }

    func info(from userInfo: [AnyHashable: Any], now: Date) -> NowPlayingInfo? {
        guard let state = userInfo["Player State"] as? String, state != "Stopped",
              let title = userInfo["Name"] as? String, !title.isEmpty
        else { return nil }

        let isPlaying = state == "Playing"
        let millis = (userInfo[durationKey] as? NSNumber)?.doubleValue

        return NowPlayingInfo(
            title: title,
            artist: userInfo["Artist"] as? String,
            album: userInfo["Album"] as? String,
            duration: millis.map { $0 / 1000 },
            elapsed: (userInfo["Playback Position"] as? NSNumber)?.doubleValue ?? 0,
            timestamp: now,
            playbackRate: isPlaying ? 1 : 0,
            isPlaying: isPlaying,
            appBundleID: bundleID,
            artworkData: nil
        )
    }
}
