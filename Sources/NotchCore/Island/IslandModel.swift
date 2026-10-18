import Observation
import SwiftUI

enum IslandKind: Equatable {
    case notch
    case pill
}

@MainActor
@Observable
final class IslandModel {
    var kind: IslandKind
    var collapsedSize: CGSize
    var isExpanded = false
    var reduceMotion = false

    static let expandedSize = CGSize(width: 500, height: 170)

    init(kind: IslandKind, collapsedSize: CGSize) {
        self.kind = kind
        self.collapsedSize = collapsedSize
    }

    var currentSize: CGSize {
        isExpanded ? Self.expandedSize : collapsedSize
    }

    var topRadius: CGFloat {
        switch kind {
        case .notch: 0
        case .pill: isExpanded ? 22 : collapsedSize.height / 2
        }
    }

    var bottomRadius: CGFloat {
        switch kind {
        case .notch: isExpanded ? 26 : 10
        case .pill: isExpanded ? 26 : collapsedSize.height / 2
        }
    }

    var contentTopInset: CGFloat {
        kind == .notch ? collapsedSize.height : 12
    }
}
