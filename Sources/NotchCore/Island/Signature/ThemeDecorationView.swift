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
        case .scanlines:
            ScanlinesView(color: appearance.accent, opacity: 0.05, spacing: layout.unit * 0.09)
        case .frame:
            RoundedRectangle(cornerRadius: max(layout.bottomRadius - layout.unit * 0.22, 0), style: .continuous)
                .strokeBorder(appearance.accent.opacity(0.35), lineWidth: max(layout.unit * 0.025, 0.75))
                .padding(layout.unit * 0.22)
                .allowsHitTesting(false)
        default:
            PatternDecoration(decoration: decoration, unit: layout.unit, accent: appearance.accent, secondary: appearance.secondary)
                .allowsHitTesting(false)
        }
    }
}
