import Observation
import SwiftUI

enum IslandKind: Equatable {
    case notch
    case pill
}

enum IslandState: Int, Comparable {
    case collapsed
    case compact
    case expanded

    static func < (lhs: IslandState, rhs: IslandState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

@MainActor
@Observable
final class IslandModel {
    var kind: IslandKind
    var collapsedSize: CGSize
    var state = IslandState.collapsed
    var reduceMotion = false

    static let expandedSize = CGSize(width: 500, height: 170)
    private static let minimumWing: CGFloat = 40
    private static let wingPadding: CGFloat = 8

    init(kind: IslandKind, collapsedSize: CGSize) {
        self.kind = kind
        self.collapsedSize = collapsedSize
    }

    var isExpanded: Bool { state == .expanded }

    var compactWing: CGFloat {
        max(collapsedSize.height + Self.wingPadding, Self.minimumWing)
    }

    var currentSize: CGSize {
        switch state {
        case .collapsed: collapsedSize
        case .compact: CGSize(width: collapsedSize.width + 2 * compactWing, height: collapsedSize.height)
        case .expanded: Self.expandedSize
        }
    }

    var topRadius: CGFloat {
        switch kind {
        case .notch: 0
        case .pill: isExpanded ? 22 : collapsedSize.height / 2
        }
    }

    var bottomRadius: CGFloat {
        switch (kind, state) {
        case (_, .expanded): 26
        case (.notch, .compact): 12
        case (.notch, .collapsed): 10
        case (.pill, _): collapsedSize.height / 2
        }
    }

    var contentTopInset: CGFloat {
        kind == .notch ? collapsedSize.height : 12
    }
}
