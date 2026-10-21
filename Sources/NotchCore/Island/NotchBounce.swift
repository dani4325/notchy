import SwiftUI

struct NotchBounce: ViewModifier {
    static let squash = 0.95
    static let stretch = 1.05
    static let press: TimeInterval = 0.08
    static let release: TimeInterval = 0.34
    static let roomRatio: CGFloat = 0.08
    static let settle: Duration = .milliseconds(Int((press + release) * 1000) + 60)

    let nudge: VolumeNudge?
    let isEnabled: Bool

    static func moves(_ direction: VolumeNudge.Direction) -> Bool {
        direction == .up || direction == .down
    }

    static func peak(for direction: VolumeNudge.Direction?) -> Double {
        switch direction {
        case .up?: squash
        case .down?: stretch
        default: 1
        }
    }

    func body(content: Content) -> some View {
        if isEnabled, let nudge, Self.moves(nudge.direction) {
            content.keyframeAnimator(initialValue: 1.0, trigger: nudge.count) { view, scale in
                view.scaleEffect(x: 1, y: scale, anchor: .top)
            } keyframes: { _ in
                CubicKeyframe(Self.peak(for: nudge.direction), duration: Self.press)
                SpringKeyframe(1, duration: Self.release, spring: .bouncy(duration: Self.release, extraBounce: 0.1))
            }
        } else {
            content
        }
    }
}
