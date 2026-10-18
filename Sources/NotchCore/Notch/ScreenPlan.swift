import CoreGraphics

struct IslandPlacement: Equatable {
    let displayID: CGDirectDisplayID
    let kind: IslandKind
    let collapsedFrame: CGRect
    let screenFrame: CGRect
    let stripHeight: CGFloat
}

enum ScreenPlan {
    static func islands(for screens: [(CGDirectDisplayID, ScreenMetrics)], nonNotchMode: NonNotchMode) -> [IslandPlacement] {
        screens.compactMap { id, metrics in
            let layout = NotchGeometry.layout(for: metrics, nonNotchMode: nonNotchMode)
            guard let frame = layout.frame else { return nil }
            return IslandPlacement(
                displayID: id,
                kind: layout.isNotch ? .notch : .pill,
                collapsedFrame: frame,
                screenFrame: metrics.frame,
                stripHeight: NotchGeometry.stripHeight(collapsed: frame, screen: metrics)
            )
        }
    }
}
