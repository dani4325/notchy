import SwiftUI

enum GateDoors {
    static let openAngle: Double = 88
    static let holdDuration = 0.14
    static let swingDuration = 0.62
    static let perspective: CGFloat = 0.55

    static func angle(progress: Double) -> Double {
        let eased = 1 - pow(1 - progress.clamped(to: 0...1), 3)
        return eased * openAngle
    }

    static func opacity(progress: Double) -> Double {
        let fadeStart = 0.7
        guard progress > fadeStart else { return 1 }
        return max(0, 1 - (progress - fadeStart) / (1 - fadeStart))
    }
}

struct GateDoorsView: View {
    let progress: Double
    let layout: IslandLayout
    let appearance: ThemeAppearance

    var body: some View {
        let half = layout.size.width / 2
        HStack(spacing: 0) {
            GateLeaf(layout: layout, appearance: appearance, isLeft: true)
                .frame(width: half)
                .rotation3DEffect(.degrees(-GateDoors.angle(progress: progress)), axis: (0, 1, 0), anchor: .leading, perspective: GateDoors.perspective)
            GateLeaf(layout: layout, appearance: appearance, isLeft: false)
                .frame(width: half)
                .rotation3DEffect(.degrees(GateDoors.angle(progress: progress)), axis: (0, 1, 0), anchor: .trailing, perspective: GateDoors.perspective)
        }
        .frame(width: layout.size.width, height: layout.bodyHeight)
        .opacity(GateDoors.opacity(progress: progress))
        .allowsHitTesting(false)
    }
}

private struct GateLeaf: View {
    let layout: IslandLayout
    let appearance: ThemeAppearance
    let isLeft: Bool

    var body: some View {
        let unit = layout.unit
        let metal = LinearGradient(
            colors: [Color(red: 0.36, green: 0.35, blue: 0.33), Color(red: 0.2, green: 0.19, blue: 0.18), Color(red: 0.3, green: 0.29, blue: 0.27)],
            startPoint: .top, endPoint: .bottom
        )

        ZStack {
            Rectangle().fill(metal)
            VStack(spacing: unit * 0.06) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.35))
                        .frame(height: max(unit * 0.03, 1))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .padding(.vertical, unit * 0.2)
            HStack {
                if !isLeft { Spacer(minLength: 0) }
                Rectangle()
                    .fill(LinearGradient(colors: [appearance.secondary, appearance.secondary.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: unit * 0.38)
                    .overlay(alignment: .center) {
                        VStack {
                            ForEach(0..<3, id: \.self) { _ in Rivet(size: unit * 0.16, tint: appearance.accent) }
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, unit * 0.3)
                    }
                    .padding(isLeft ? .leading : .trailing, unit * 0.55)
                if isLeft { Spacer(minLength: 0) }
            }
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(width: max(unit * 0.04, 1))
                .frame(maxWidth: .infinity, alignment: isLeft ? .trailing : .leading)
        }
    }
}

struct Rivet: View {
    let size: CGFloat
    let tint: Color

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color.white.opacity(0.85), tint, tint.opacity(0.4)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.6))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.6), radius: size * 0.15, y: size * 0.1)
    }
}
