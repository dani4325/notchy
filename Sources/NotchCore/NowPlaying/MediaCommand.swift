enum MediaCommand: Sendable {
    case togglePlayPause
    case nextTrack
    case previousTrack

    var adapterID: Int {
        switch self {
        case .togglePlayPause: 2
        case .nextTrack: 4
        case .previousTrack: 5
        }
    }

    var appleScriptVerb: String {
        switch self {
        case .togglePlayPause: "playpause"
        case .nextTrack: "next track"
        case .previousTrack: "previous track"
        }
    }
}
