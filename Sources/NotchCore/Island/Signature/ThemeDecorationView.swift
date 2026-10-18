import SwiftUI

struct ScanlinesView: View {
    let color: Color
    let opacity: Double
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            let step = max(spacing, 1.5)
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: step * 0.35)), with: .color(color.opacity(opacity)))
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

struct ThemeDecorationView: View {
    let decoration: ThemeDecoration
    let layout: IslandLayout
    let appearance: ThemeAppearance

    var body: some View {
        switch decoration {
        case .nixieTerminal:
            ScanlinesView(color: appearance.accent, opacity: 0.05, spacing: layout.unit * 0.09)
        case .wallPlating:
            WallPlating(layout: layout, appearance: appearance)
        case .menacing:
            MenacingPattern(layout: layout, appearance: appearance)
        case .reiatsu:
            ReiatsuAura(layout: layout, appearance: appearance)
        case .orbits:
            OrbitChart(layout: layout, appearance: appearance, progress: 1, opacity: 0.16)
        default:
            PatternDecoration(decoration: decoration, unit: layout.unit, accent: appearance.accent, secondary: appearance.secondary)
                .allowsHitTesting(false)
        }
    }
}

private struct WallPlating: View {
    let layout: IslandLayout
    let appearance: ThemeAppearance

    var body: some View {
        let inset = layout.unit * 0.22
        let rivet = layout.unit * 0.13

        ZStack {
            RoundedRectangle(cornerRadius: max(layout.bottomRadius - inset, 0), style: .continuous)
                .strokeBorder(appearance.accent.opacity(0.35), lineWidth: max(layout.unit * 0.025, 0.75))
                .padding(inset)
            VStack {
                HStack { Rivet(size: rivet, tint: appearance.accent); Spacer(); Rivet(size: rivet, tint: appearance.accent) }
                Spacer()
                HStack { Rivet(size: rivet, tint: appearance.accent); Spacer(); Rivet(size: rivet, tint: appearance.accent) }
            }
            .padding(inset * 1.8)
        }
        .allowsHitTesting(false)
    }
}

private struct MenacingPattern: View {
    let layout: IslandLayout
    let appearance: ThemeAppearance

    var body: some View {
        Canvas { context, size in
            let stripe = layout.unit * 0.5
            var x = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(path, with: .color(appearance.secondary.opacity(0.07)), lineWidth: stripe * 0.35)
                x += stripe
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ReiatsuAura: View {
    let layout: IslandLayout
    let appearance: ThemeAppearance

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [appearance.secondary.opacity(0.16), .clear],
                center: UnitPoint(x: 0.15, y: 0.6), startRadius: 0, endRadius: layout.bodyHeight
            )
            Canvas { context, size in
                var scar = Path()
                scar.move(to: CGPoint(x: size.width * 0.58, y: size.height))
                scar.addLine(to: CGPoint(x: size.width * 0.86, y: 0))
                context.stroke(scar, with: .color(appearance.text.opacity(0.06)), lineWidth: layout.unit * 0.05)
            }
        }
        .allowsHitTesting(false)
    }
}
