import SwiftUI

struct LegibilityNeeds: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let text = LegibilityNeeds(rawValue: 1)
    static let graphics = LegibilityNeeds(rawValue: 2)
    static let accent = LegibilityNeeds(rawValue: 4)
}

struct LegibilityMark: Equatable, Sendable {
    static let space = "notchy.island"

    let needs: LegibilityNeeds
    let rect: CGRect
}

struct LegibilityMarksKey: PreferenceKey {
    static let defaultValue: [LegibilityMark] = []

    static func reduce(value: inout [LegibilityMark], nextValue: () -> [LegibilityMark]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    @ViewBuilder
    func legibilityMarkIfNeeded(_ needs: LegibilityNeeds) -> some View {
        if needs.isEmpty { self } else { legibilityMark(needs) }
    }

    func legibilityMark(_ needs: LegibilityNeeds, letterHeight: CGFloat? = nil) -> some View {
        background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(LegibilityMark.space))
                let trim = letterHeight.map { max((frame.height - $0) / 2, 0) } ?? 0
                Color.clear.preference(
                    key: LegibilityMarksKey.self,
                    value: [LegibilityMark(needs: needs, rect: frame.insetBy(dx: 0, dy: trim))]
                )
            }
        }
    }
}
