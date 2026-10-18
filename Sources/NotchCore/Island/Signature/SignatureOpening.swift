import SwiftUI

struct SignatureEffect {
    let kind: OpenAnimation
    let duration: Double

    init(_ kind: OpenAnimation) {
        self.kind = kind
        duration = switch kind {
        case .gate: GateDoors.holdDuration + GateDoors.swingDuration
        case .menacing: 0.95
        case .slash: 0.5
        case .orbit: 0.85
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
        case (true, .gate), (true, .menacing), (true, .slash), (true, .orbit):
            let effect = SignatureEffect(kind)
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, progress in
                view.overlay(alignment: .top) {
                    if !SignatureEffect.isFinished(progress: progress) {
                        SignatureOverlay(kind: kind, progress: progress, layout: layout, appearance: appearance)
                    }
                }
            } keyframes: { _ in
                LinearKeyframe(0, duration: 0.001)
                if kind == .gate {
                    LinearKeyframe(0, duration: GateDoors.holdDuration)
                    LinearKeyframe(1, duration: GateDoors.swingDuration)
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
            case .gate:
                GateDoorsView(progress: progress, layout: layout, appearance: appearance)
            case .menacing:
                MenacingBurst(progress: progress, layout: layout, appearance: appearance)
            case .slash:
                SlashStreak(progress: progress, layout: layout, appearance: appearance)
            case .orbit:
                OrbitChart(layout: layout, appearance: appearance, progress: progress, opacity: 1 - progress * 0.85)
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

struct MenacingBurst: View {
    let progress: Double
    let layout: IslandLayout
    let appearance: ThemeAppearance

    static let glyph = "ゴ"
    static let placements: [(x: CGFloat, y: CGFloat, scale: CGFloat, delay: Double)] = [
        (0.08, 0.25, 1.0, 0), (0.16, 0.62, 0.8, 0.08), (0.84, 0.3, 1.1, 0.04), (0.92, 0.7, 0.85, 0.12), (0.5, 0.82, 0.7, 0.16),
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(Self.placements.enumerated()), id: \.offset) { index, spot in
                let local = ((progress - spot.delay) / 0.45).clamped(to: 0...1)
                let pop = local < 0.25 ? local / 0.25 * 1.25 : 1.25 - (local - 0.25) * 0.33
                let fade = progress > 0.7 ? max(0, 1 - (progress - 0.7) / 0.3) : 1
                let shake = sin(progress * 60 + Double(index)) * layout.unit * 0.04

                Text(Self.glyph)
                    .font(.custom("Dela Gothic One", size: layout.unit * 0.95 * spot.scale))
                    .foregroundStyle(LinearGradient(colors: [appearance.secondary, appearance.accent], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.6), radius: layout.unit * 0.06, x: layout.unit * 0.04, y: layout.unit * 0.04)
                    .scaleEffect(local > 0 ? pop : 0.01)
                    .rotationEffect(.degrees(-8 + Double(index) * 4))
                    .offset(x: shake)
                    .opacity(local > 0 ? fade : 0)
                    .position(x: proxy.size.width * spot.x, y: proxy.size.height * spot.y)
            }
        }
    }
}

struct SlashStreak: View {
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
            context.addFilter(.shadow(color: appearance.secondary.opacity(0.9), radius: layout.unit * 0.25))
            context.stroke(trimmed, with: .color(appearance.accent.opacity(0.8)), style: StrokeStyle(lineWidth: layout.unit * 0.18, lineCap: .round))
            context.stroke(trimmed, with: .color(.white), style: StrokeStyle(lineWidth: layout.unit * 0.07, lineCap: .round))
        }
        .opacity(fade)
    }
}

struct OrbitChart: View {
    let layout: IslandLayout
    let appearance: ThemeAppearance
    let progress: Double
    let opacity: Double

    static let rings: [CGFloat] = [0.18, 0.32, 0.48, 0.66]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.55)
            let grow = CGFloat(0.35 + 0.65 * (1 - pow(1 - progress, 3)))
            for (index, ring) in Self.rings.enumerated() {
                let radiusX = size.width * ring * grow
                let radiusY = radiusX * 0.32
                let rect = CGRect(x: center.x - radiusX, y: center.y - radiusY, width: radiusX * 2, height: radiusY * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(appearance.accent.opacity(opacity * 0.8)), lineWidth: max(layout.unit * 0.02, 0.6))
                let angle = progress * .pi * (1.2 + Double(index) * 0.35) + Double(index) * 1.7
                let planet = CGPoint(x: center.x + cos(angle) * radiusX, y: center.y + sin(angle) * radiusY)
                let planetSize = layout.unit * (0.09 + CGFloat(index) * 0.02)
                context.fill(Path(ellipseIn: CGRect(x: planet.x - planetSize / 2, y: planet.y - planetSize / 2, width: planetSize, height: planetSize)),
                             with: .color(appearance.secondary.opacity(opacity)))
            }
            let sun = layout.unit * 0.22
            context.fill(Path(ellipseIn: CGRect(x: center.x - sun / 2, y: center.y - sun / 2, width: sun, height: sun)),
                         with: .color(appearance.accent.opacity(opacity)))
            for star in 0..<18 {
                let seed = Double(star) * 12.9898
                let x = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                let y = (sin(seed * 1.7) * 24634.6345).truncatingRemainder(dividingBy: 1)
                let point = CGPoint(x: abs(x) * size.width, y: abs(y) * size.height)
                context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 1.4, height: 1.4)), with: .color(appearance.text.opacity(opacity * 0.7)))
            }
        }
    }
}
