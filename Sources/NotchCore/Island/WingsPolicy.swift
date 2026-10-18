import Foundation

public enum WingsMode: String, CaseIterable, Sendable {
    case always
    case withMusic
    case never
}

enum WingsPhase: Equatable {
    case idle
    case playing
    case paused(since: Date)

    static func next(after current: WingsPhase, isPlaying: Bool, hasMedia: Bool, now: Date) -> WingsPhase {
        guard hasMedia else { return .idle }
        if isPlaying { return .playing }
        switch current {
        case .playing: return .paused(since: now)
        case .paused, .idle: return current
        }
    }
}

enum WingsPolicy {
    static let pauseGrace: TimeInterval = 60

    static func isVisible(mode: WingsMode, phase: WingsPhase, now: Date, menusCollide: Bool = false) -> Bool {
        guard !menusCollide else { return false }
        return switch (mode, phase) {
        case (.always, _): true
        case (.never, _): false
        case (.withMusic, .playing): true
        case (.withMusic, .idle): false
        case (.withMusic, .paused(let since)): now < since.addingTimeInterval(pauseGrace)
        }
    }

    static func hideDeadline(mode: WingsMode, phase: WingsPhase) -> Date? {
        guard mode == .withMusic, case .paused(let since) = phase else { return nil }
        return since.addingTimeInterval(pauseGrace)
    }
}
