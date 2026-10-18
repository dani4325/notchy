import SwiftUI

struct MotionPolicy {
    let reduceMotion: Bool

    static let openSpring = Animation.spring(duration: 0.48, bounce: 0.3)
    static let closeSpring = Animation.spring(duration: 0.34, bounce: 0)
    static let fade = Animation.easeInOut(duration: 0.18)

    static let openDuration: Duration = .milliseconds(480)
    static let closeDuration: Duration = .milliseconds(340)

    var animatesShape: Bool { !reduceMotion }

    var contentScale: CGFloat { reduceMotion ? 1 : 0.86 }

    func shapeAnimation(expanding: Bool) -> Animation? {
        guard animatesShape else { return nil }
        return expanding ? Self.openSpring : Self.closeSpring
    }

    var contentAnimation: Animation {
        reduceMotion ? Self.fade : .smooth(duration: 0.28)
    }

    @MainActor
    static var current: MotionPolicy {
        MotionPolicy(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}
