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
    var stripHeight: CGFloat
    var state = IslandState.collapsed
    var reduceMotion = false

    static let expandedSize = CGSize(width: 500, height: 170)
    private static let minimumWing: CGFloat = 40
    private static let wingPadding: CGFloat = 8

    init(kind: IslandKind, collapsedSize: CGSize, stripHeight: CGFloat) {
        self.kind = kind
        self.collapsedSize = collapsedSize
        self.stripHeight = stripHeight
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

    var stemHeight: CGFloat {
        isExpanded ? stripHeight : 0
    }

    var topRadius: CGFloat {
        kind == .notch ? 0 : collapsedSize.height / 2
    }

    var bodyTopRadius: CGFloat {
        isExpanded ? 18 : topRadius
    }

    var junctionRadius: CGFloat {
        isExpanded ? 10 : 0
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
        stripHeight
    }
}
