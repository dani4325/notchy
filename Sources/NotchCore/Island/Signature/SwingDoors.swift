import SwiftUI

enum SwingDoors {
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

struct SwingDoorsView: View {
    let progress: Double
    let layout: IslandLayout
    let appearance: ThemeAppearance

    var body: some View {
        let half = layout.size.width / 2
        HStack(spacing: 0) {
            DoorLeaf(layout: layout, appearance: appearance, seam: .trailing)
                .frame(width: half)
                .rotation3DEffect(.degrees(-SwingDoors.angle(progress: progress)), axis: (0, 1, 0), anchor: .leading, perspective: SwingDoors.perspective)
            DoorLeaf(layout: layout, appearance: appearance, seam: .leading)
                .frame(width: half)
                .rotation3DEffect(.degrees(SwingDoors.angle(progress: progress)), axis: (0, 1, 0), anchor: .trailing, perspective: SwingDoors.perspective)
        }
        .frame(width: layout.size.width, height: layout.bodyHeight)
        .opacity(SwingDoors.opacity(progress: progress))
        .allowsHitTesting(false)
    }
}

private struct DoorLeaf: View {
    let layout: IslandLayout
    let appearance: ThemeAppearance
    let seam: Alignment

    var body: some View {
        Rectangle()
            .fill(appearance.panel)
            .overlay(alignment: seam) {
                Rectangle()
                    .fill(appearance.accentGraphic)
                    .frame(width: max(layout.unit * 0.04, 1))
            }
    }
}
