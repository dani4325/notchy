import SwiftUI

struct GlitchState: Equatable {
    let split: CGFloat
    let jitter: CGFloat
    let scan: Double
    let flicker: Double
    let duration: Double

    static let rest = GlitchState(split: 0, jitter: 0, scan: 0, flicker: 1, duration: 0.14)

    static let bursts: [GlitchState] = [
        GlitchState(split: 0.16, jitter: -0.1, scan: 0.55, flicker: 0.45, duration: 0.04),
        GlitchState(split: 0.05, jitter: 0.13, scan: 0.35, flicker: 1, duration: 0.05),
        GlitchState(split: 0.24, jitter: -0.05, scan: 0.7, flicker: 0.65, duration: 0.05),
        GlitchState(split: 0.08, jitter: 0.03, scan: 0.3, flicker: 1, duration: 0.06),
        GlitchState(split: 0.03, jitter: 0, scan: 0.12, flicker: 0.85, duration: 0.07),
    ]

    static var phases: [GlitchState] { [rest] + bursts }
    static var keyframeSequence: [GlitchState] { bursts + [rest] }
    static var totalDuration: Double { keyframeSequence.reduce(0) { $0 + $1.duration } }
}

struct GlitchLayer<Content: View>: View {
    let state: GlitchState
    let unit: CGFloat
    let tint: Color
    let content: Content

    var body: some View {
        if state == .rest {
            content
        } else {
            content
                .offset(x: state.jitter * unit)
                .overlay {
                    content
                        .colorMultiply(Color(red: 1, green: 0.15, blue: 0.35))
                        .offset(x: state.split * unit)
                        .blendMode(.screen)
                        .opacity(0.7)
                        .allowsHitTesting(false)
                }
                .overlay {
                    content
                        .colorMultiply(Color(red: 0.1, green: 1, blue: 0.85))
                        .offset(x: -state.split * unit)
                        .blendMode(.screen)
                        .opacity(0.7)
                        .allowsHitTesting(false)
                }
                .overlay { ScanlinesView(color: tint, opacity: state.scan, spacing: unit * 0.08) }
                .opacity(state.flicker)
        }
    }
}

struct GlitchOpening: ViewModifier {
    let trigger: Int
    let isEnabled: Bool
    let unit: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        if isEnabled {
            content.phaseAnimator(GlitchState.phases, trigger: trigger) { view, state in
                GlitchLayer(state: state, unit: unit, tint: tint, content: view)
            } animation: { state in
                .linear(duration: state.duration)
            }
        } else {
            content
        }
    }
}
