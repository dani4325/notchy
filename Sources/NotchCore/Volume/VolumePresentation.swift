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
    private(set) var phase = Phase.hidden

    init(allowsCompact: Bool) {
        self.allowsCompact = allowsCompact
    }

    mutating func press() -> Duration {
        if phase == .compact { return Self.compactHold }
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

struct VolumeBump: Equatable, Sendable {
    let limit: VolumeLimit
    let count: Int
}
