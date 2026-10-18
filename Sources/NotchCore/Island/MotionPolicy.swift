import SwiftUI

struct MotionPolicy {
    let reduceMotion: Bool
    let openAnimation: OpenAnimation

    init(reduceMotion: Bool, openAnimation: OpenAnimation = .spring) {
        self.reduceMotion = reduceMotion
        self.openAnimation = openAnimation
    }

    static let closeSpring = Animation.spring(duration: 0.34, bounce: 0)
    static let fade = Animation.easeInOut(duration: 0.18)

    static let openDuration: Duration = .milliseconds(560)
    static let closeDuration: Duration = .milliseconds(340)

    var animatesShape: Bool { !reduceMotion && openAnimation != .fade }

    var contentScale: CGFloat { animatesShape ? 0.86 : 1 }

    func shapeAnimation(expanding: Bool) -> Animation? {
        guard animatesShape else { return nil }
        guard expanding else { return Self.closeSpring }
        return switch openAnimation {
        case .spring: .spring(duration: 0.48, bounce: 0.3)
        case .bouncy: .spring(duration: 0.56, bounce: 0.45)
        case .smooth: .smooth(duration: 0.42)
        case .fade: nil
        }
    }

    var contentAnimation: Animation {
        animatesShape ? .smooth(duration: 0.28) : Self.fade
    }

    @MainActor
    static func current(openAnimation: OpenAnimation) -> MotionPolicy {
        MotionPolicy(
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            openAnimation: openAnimation
        )
    }
}
