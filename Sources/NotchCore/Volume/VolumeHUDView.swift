import SwiftUI

struct VolumeHUDView: View {
    let layout: IslandLayout
    let reading: VolumeReading
    var nudge: VolumeNudge?
    var step: (MediaKeyKind) -> Void = { _ in }

    @Environment(\.themeAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var level: Float { reading.isMuted ? 0 : reading.level }
    private var percent: Int { Int((level * 100).rounded()) }

    var body: some View {
        VStack(spacing: layout.textSpacing * 2.5) {
            HStack(spacing: 0) {
                stepButton("minus", label: "Bajar volumen", kind: .volumeDown)
                Spacer(minLength: 0)
                readout
                Spacer(minLength: 0)
                stepButton("plus", label: "Subir volumen", kind: .volumeUp)
            }
            if let output = reading.output {
                (Text(Image(systemName: output.kind.symbol)) + Text(verbatim: " " + output.name))
                    .font(appearance.bodyFont(layout.subtitleSize))
                    .foregroundStyle(appearance.secondaryTextColor)
                    .lineLimit(1)
                    .legibilityMark(.text, letterHeight: layout.subtitleSize)
            }
            SegmentedLevelBar(
                level: level,
                colors: appearance.levelSegmentColors,
                track: appearance.barTrackColor,
                nudge: nudge
            )
            .frame(height: layout.volumeSegmentHeight)
            .legibilityMark(.accent)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, layout.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : Self.change, value: percent)
        .animation(reduceMotion ? nil : Self.change, value: reading.isMuted)
    }

    private static let change = Animation.snappy(duration: 0.25)

    private var readout: some View {
        HStack(spacing: layout.unit * 0.22) {
            VolumeSymbol(reading: reading, size: layout.volumeNumberSize * 0.8)
            Group {
                if reading.isMuted {
                    Text("Silencio")
                } else if appearance.theme.decoration == .nixieTerminal {
                    NixieReadoutView(text: "\(percent)", height: layout.volumeNumberSize * 1.2, glow: appearance.secondaryText)
                } else {
                    Text("\(percent) %")
                        .monospacedDigit()
                        .contentTransition(reduceMotion ? .identity : .numericText(value: Double(percent)))
                }
            }
            .font(appearance.titleFont(layout.volumeNumberSize))
            .foregroundStyle(appearance.text)
        }
        .foregroundStyle(appearance.text)
        .lineLimit(1)
        .legibilityMark(.text, letterHeight: layout.volumeNumberSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.isMuted ? Text("Sonido silenciado") : Text("Volumen \(percent) por ciento"))
        .accessibilityValue(reading.output.map { Text(verbatim: $0.name) } ?? Text(verbatim: ""))
    }

    private func stepButton(_ symbol: String, label: LocalizedStringKey, kind: MediaKeyKind) -> some View {
        Button { step(kind) } label: {
            Image(systemName: symbol).font(.system(size: layout.volumeStepIconSize, weight: .semibold))
        }
        .buttonStyle(TransportButtonStyle(diameter: layout.controlDiameter, tint: appearance.text, pressed: appearance.accentGraphic))
        .accessibilityLabel(label)
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
