import SwiftUI

struct VolumeHUDView: View {
    let layout: IslandLayout
    let reading: VolumeReading
    var bump: VolumeBump?

    @Environment(\.themeAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var level: Float { reading.isMuted ? 0 : reading.level }
    private var percent: Int { Int((level * 100).rounded()) }

    var body: some View {
        PanelRow(layout: layout, subtitle: outputLine) {
            PanelTile(layout: layout) {
                VolumeSymbol(reading: reading, size: layout.artworkSide * 0.34)
                    .foregroundStyle(appearance.text)
            }
        } title: {
            if reading.isMuted {
                Text("Silencio")
            } else if appearance.theme.decoration == .nixieTerminal {
                NixieReadoutView(text: "\(percent)", height: layout.titleSize * 1.2, glow: appearance.secondaryText)
            } else {
                Text("\(percent) %")
                    .monospacedDigit()
                    .contentTransition(reduceMotion ? .identity : .numericText(value: Double(percent)))
            }
        } accessory: {
            EmptyView()
        } bar: {
            PanelLevel(layout: layout, fraction: Double(level), bump: bump)
        } trailing: {
            Color.clear
        }
        .animation(reduceMotion ? nil : Self.change, value: percent)
        .animation(reduceMotion ? nil : Self.change, value: reading.isMuted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.isMuted ? Text("Sonido silenciado") : Text("Volumen \(percent) por ciento"))
        .accessibilityValue(reading.output.map { Text(verbatim: $0.name) } ?? Text(verbatim: ""))
    }

    private static let change = Animation.snappy(duration: 0.25)

    private var outputLine: Text? {
        reading.output.map { Text(Image(systemName: $0.kind.symbol)) + Text(verbatim: " " + $0.name) }
    }
}

struct VolumeSymbol: View {
    let reading: VolumeReading
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(
            systemName: reading.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill",
            variableValue: reading.isMuted ? nil : Double(reading.level)
        )
        .font(.system(size: size, weight: .semibold))
        .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
    }
}
