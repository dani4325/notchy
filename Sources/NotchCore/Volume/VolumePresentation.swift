import Foundation

struct VolumePresentation: Equatable {
    enum Phase: Equatable {
        case hidden
        case expanded
        case compact
    }

    static let expandedHold: Duration = .seconds(1)
    static let compactHold: Duration = .milliseconds(1500)

    let allowsCompact: Bool
    let compactOnly: Bool
    private(set) var phase = Phase.hidden

    init(allowsCompact: Bool, compactOnly: Bool = false) {
        self.allowsCompact = allowsCompact
        self.compactOnly = compactOnly
    }

    mutating func press() -> Duration {
        if phase == .compact || compactOnly {
            phase = .compact
            return Self.compactHold
        }
        phase = .expanded
        return Self.expandedHold
    }

    mutating func tick() -> Duration? {
        switch phase {
        case .expanded where allowsCompact:
            phase = .compact
            return Self.compactHold
        case .expanded, .compact:
            phase = .hidden
            return nil
        case .hidden:
            return nil
        }
    }
}

public enum VolumeLimit: Equatable, Sendable {
    case top
    case bottom

    static func reached(before: Float, after: Float, kind: MediaKeyKind) -> VolumeLimit? {
        switch kind {
        case .volumeUp where before >= 1 && after >= 1: .top
        case .volumeDown where before <= 0 && after <= 0: .bottom
        default: nil
        }
    }
}

public struct VolumeNudge: Equatable, Sendable {
    public enum Direction: Equatable, Sendable {
        case up
        case down
        case mute
        case unmute

        static func of(from previous: VolumeReading?, to current: VolumeReading, key: MediaKeyKind?) -> Direction? {
            guard let previous else { return nil }
            if previous.isMuted != current.isMuted { return current.isMuted ? .mute : .unmute }
            if current.level > previous.level { return .up }
            if current.level < previous.level { return .down }
            return switch key {
            case .volumeUp?: .up
            case .volumeDown?: .down
            default: nil
            }
        }
    }

    let direction: Direction
    let limit: VolumeLimit?
    let count: Int
}
