import SwiftUI

struct SignatureEffect {
    let kind: OpenAnimation
    let duration: Double

    init(_ kind: OpenAnimation) {
        self.kind = kind
        duration = switch kind {
        case .doors: SwingDoors.holdDuration + SwingDoors.swingDuration
        case .cut: 0.5
        default: 0
        }
    }

    static func isFinished(progress: Double) -> Bool {
        progress >= 1
    }
}

struct SignatureOpening: ViewModifier {
    let kind: OpenAnimation
    let trigger: Int
    let isEnabled: Bool
    let layout: IslandLayout
    let appearance: ThemeAppearance

    func body(content: Content) -> some View {
        switch (isEnabled, kind) {
        case (true, .glitch):
            content.modifier(GlitchOpening(trigger: trigger, isEnabled: true, unit: layout.unit, tint: appearance.accent))
        case (true, .doors), (true, .cut):
            let effect = SignatureEffect(kind)
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, progress in
                view.overlay(alignment: .top) {
                    if !SignatureEffect.isFinished(progress: progress) {
                        SignatureOverlay(kind: kind, progress: progress, layout: layout, appearance: appearance)
                    }
                }
            } keyframes: { _ in
                LinearKeyframe(0, duration: 0.001)
                if kind == .doors {
                    LinearKeyframe(0, duration: SwingDoors.holdDuration)
                    LinearKeyframe(1, duration: SwingDoors.swingDuration)
                } else {
                    LinearKeyframe(1, duration: effect.duration)
                }
            }
        default:
            content
        }
    }
}

struct SignatureOverlay: View {
    let kind: OpenAnimation
    let progress: Double
    let layout: IslandLayout
    let appearance: ThemeAppearance

    var body: some View {
        let bodySize = layout.bodyRect.size
        Group {
            switch kind {
            case .doors:
                SwingDoorsView(progress: progress, layout: layout, appearance: appearance)
            case .cut:
                CutStreak(progress: progress, layout: layout, appearance: appearance)
            default:
                EmptyView()
            }
        }
        .frame(width: bodySize.width, height: bodySize.height)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: layout.bodyTopRadius, bottomLeadingRadius: layout.bottomRadius,
            bottomTrailingRadius: layout.bottomRadius, topTrailingRadius: layout.bodyTopRadius, style: .continuous
        ))
        .padding(.top, layout.stem.height)
        .allowsHitTesting(false)
    }
}

struct CutStreak: View {
    let progress: Double
    let layout: IslandLayout
    let appearance: ThemeAppearance

    var body: some View {
        let draw = (progress / 0.45).clamped(to: 0...1)
        let fade = progress > 0.45 ? max(0, 1 - (progress - 0.45) / 0.55) : 1

        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.06, y: size.height * 0.92))
            path.addQuadCurve(
                to: CGPoint(x: size.width * 0.94, y: size.height * 0.08),
                control: CGPoint(x: size.width * 0.45, y: size.height * 0.62)
            )
            let trimmed = path.trimmedPath(from: max(0, draw - 0.35), to: draw)
            context.stroke(trimmed, with: .color(appearance.accentGraphic), style: StrokeStyle(lineWidth: layout.unit * 0.12, lineCap: .butt))
        }
        .opacity(fade)
    }
}
