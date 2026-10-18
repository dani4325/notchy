import Foundation

enum MediaKeyKind: Equatable, Sendable {
    case volumeUp
    case volumeDown
    case mute
}

struct MediaKey: Equatable, Sendable {
    let kind: MediaKeyKind
    let isDown: Bool
    let isRepeat: Bool

    private static let soundUp = 0
    private static let soundDown = 1
    private static let mute = 7
    private static let keyDownState = 0xA

    init(kind: MediaKeyKind, isDown: Bool, isRepeat: Bool) {
        self.kind = kind
        self.isDown = isDown
        self.isRepeat = isRepeat
    }

    init?(data1: Int) {
        let code = (data1 & 0xFFFF_0000) >> 16
        let flags = data1 & 0xFFFF
        switch code {
        case Self.soundUp: kind = .volumeUp
        case Self.soundDown: kind = .volumeDown
        case Self.mute: kind = .mute
        default: return nil
        }
        isDown = (flags & 0xFF00) >> 8 == Self.keyDownState
        isRepeat = flags & 0x1 == 1
    }
}

enum VolumeStep {
    static let steps: Float = 16

    static func apply(_ kind: MediaKeyKind, to level: Float) -> Float {
        let position = level * steps
        let next: Float = switch kind {
        case .volumeUp: (position + 0.001).rounded(.down) + 1
        case .volumeDown: (position - 0.001).rounded(.up) - 1
        case .mute: position
        }
        return min(max(next / steps, 0), 1)
    }
}

public struct VolumeReading: Equatable, Sendable {
    public let level: Float
    public let isMuted: Bool

    static func isChange(from previous: VolumeReading?, to current: VolumeReading) -> Bool {
        guard let previous else { return false }
        return previous != current
    }
}
