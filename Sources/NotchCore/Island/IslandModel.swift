import Observation
import SwiftUI

enum IslandKind: Equatable {
    case notch
    case pill
}

enum IslandActivity: Equatable {
    case power(PowerEvent)
    case volume(VolumeReading, VolumeNudge?)
    case greeting

    var duration: Duration {
        switch self {
        case .power: .seconds(3)
        case .volume: .milliseconds(1500)
        case .greeting: .seconds(4)
        }
    }

    func isSameKind(as other: IslandActivity?) -> Bool {
        switch (self, other) {
        case (.power, .power?), (.volume, .volume?), (.greeting, .greeting?): true
        default: false
        }
    }
}

enum IslandPage: Equatable {
    case main
    case shelf
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
    var openAnimation = OpenAnimation.spring
    var openCount = 0
    var activity: IslandActivity?
    var page = IslandPage.main
    var isDropTargeted = false
    var shapeStyle = ThemeShape.standard
    var legibilityMarks: [LegibilityMark] = []
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

    var layout: IslandLayout {
        IslandLayout(notch: collapsedSize, stemHeight: kind == .pill ? stripHeight : nil, shape: shapeStyle)
    }

    var currentSize: CGSize {
        switch state {
        case .collapsed: collapsedSize
        case .compact: CGSize(width: collapsedSize.width + 2 * compactWing, height: collapsedSize.height)
        case .expanded: expandedSize
        }
    }

    var expandedSize: CGSize {
        layout.size
    }

    var stemHeight: CGFloat {
        isExpanded ? layout.stem.height : 0
    }

    var topRadius: CGFloat {
        kind == .notch ? 0 : collapsedSize.height / 2
    }

    var bodyTopRadius: CGFloat {
        isExpanded ? layout.bodyTopRadius : topRadius
    }

    var junctionRadius: CGFloat {
        isExpanded ? layout.junctionRadius : 0
    }

    var bottomRadius: CGFloat {
        switch (kind, state) {
        case (_, .expanded): layout.bottomRadius
        case (.notch, .compact): 12
        case (.notch, .collapsed): 10
        case (.pill, _): collapsedSize.height / 2
        }
    }

    var shape: IslandShape {
        IslandShape(
            stemWidth: collapsedSize.width,
            stemHeight: stemHeight,
            topRadius: topRadius,
            bodyTopRadius: bodyTopRadius,
            bottomRadius: bottomRadius,
            junctionRadius: junctionRadius
        )
    }
}
