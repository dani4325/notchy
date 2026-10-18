import SwiftUI

struct VolumeHUDView: View {
    let layout: IslandLayout
    let reading: VolumeReading

    @Environment(\.themeAppearance) private var appearance

    private static let segments = Int(VolumeStep.steps)

    private var level: Float { reading.isMuted ? 0 : reading.level }
    private var percent: Int { Int((level * 100).rounded()) }

    private var symbol: String {
        if reading.isMuted || level == 0 { return "speaker.slash.fill" }
        if level < 0.34 { return "speaker.wave.1.fill" }
        if level < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var body: some View {
        HStack(spacing: layout.columnGap) {
            Image(systemName: symbol)
                .font(.system(size: layout.artworkSide * 0.34, weight: .semibold))
                .foregroundStyle(appearance.accent)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: layout.artworkSide * 0.6)

            VStack(alignment: .leading, spacing: layout.textSpacing * 2) {
                Text(reading.isMuted ? "SILENCIO" as LocalizedStringKey : "VOLUMEN")
                    .font(appearance.labelFont(layout.labelSize))
                    .tracking(appearance.theme.typography.labelTracking)
                    .foregroundStyle(appearance.accent)
                HStack(spacing: layout.unit * 0.06) {
                    ForEach(0..<Self.segments, id: \.self) { index in
                        let lit = Float(index) < level * Float(Self.segments) - 0.001
                        Capsule()
                            .fill(lit ? AnyShapeStyle(LinearGradient(colors: [appearance.accent, appearance.secondary], startPoint: .bottom, endPoint: .top))
                                      : AnyShapeStyle(appearance.text.opacity(0.14)))
                            .frame(height: layout.unit * 0.42)
                            .shadow(color: lit ? appearance.accent.opacity(0.5) : .clear, radius: layout.unit * 0.08)
                    }
                }
                .animation(.snappy(duration: 0.18), value: level)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if appearance.theme.decoration == .nixieTerminal {
                    NixieReadoutView(text: "\(percent)", height: layout.titleSize * 1.8, glow: appearance.secondary)
                } else {
                    Text("\(percent)")
                        .font(appearance.titleFont(layout.titleSize * 1.6))
                        .monospacedDigit()
                        .foregroundStyle(appearance.text)
                }
            }
            .frame(width: layout.controlsWidth * 0.75, alignment: .trailing)
        }
        .padding(.horizontal, layout.padding)
        .frame(width: layout.size.width, height: layout.bodyHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.isMuted ? Text("Sonido silenciado") : Text("Volumen \(percent) por ciento"))
    }
}
