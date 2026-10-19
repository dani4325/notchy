import SwiftUI

struct ChargingView: View {
    let layout: IslandLayout
    let event: PowerEvent

    @Environment(\.themeAppearance) private var appearance

    private var level: Double { Double(event.percent).clamped(to: 0...100) / 100 }

    var body: some View {
        HStack(spacing: layout.columnGap) {
            BatteryGlyph(level: level, isConnected: event.isConnected, height: layout.artworkSide * 0.5, appearance: appearance)
                .frame(width: layout.artworkSide, height: layout.artworkSide)

            VStack(alignment: .leading, spacing: layout.textSpacing) {
                Text(headline)
                    .font(appearance.labelFont(layout.labelSize))
                    .tracking(appearance.theme.typography.labelTracking)
                    .foregroundStyle(appearance.accentText)
                Group {
                    if appearance.theme.decoration == .nixieTerminal {
                        NixieReadoutView(text: "\(event.percent)", height: layout.titleSize * 2.2, glow: appearance.secondaryText)
                    } else {
                        Text("\(event.percent) %")
                            .font(appearance.titleFont(layout.titleSize * 2.1))
                            .foregroundStyle(appearance.text)
                    }
                }
                Text(detail)
                    .font(appearance.bodyFont(layout.subtitleSize))
                    .foregroundStyle(appearance.text.opacity(0.7))
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, layout.padding)
        .frame(width: layout.size.width, height: layout.bodyHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(headline), \(event.percent) %")
    }

    private var headline: String {
        switch event {
        case .connected: String(localized: "CARGANDO")
        case .disconnected: String(localized: "CON BATERÍA")
        case .low: String(localized: "BATERÍA BAJA")
        case .full: String(localized: "CARGA COMPLETA")
        }
    }

    private var detail: String {
        switch event {
        case .connected: String(localized: "Cargador conectado")
        case .disconnected: String(localized: "Cargador desconectado")
        case .low: String(localized: "Conecta el cargador pronto")
        case .full: String(localized: "Puedes desconectar el cargador")
        }
    }
}

private struct BatteryGlyph: View {
    let level: Double
    let isConnected: Bool
    let height: CGFloat
    let appearance: ThemeAppearance

    var body: some View {
        let width = height * 2
        let corner = height * 0.22
        let fill: Color = level <= 0.2 && !isConnected ? .red : appearance.accentGraphic

        HStack(spacing: height * 0.06) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(appearance.text.opacity(0.75), lineWidth: max(height * 0.07, 1))
                RoundedRectangle(cornerRadius: corner * 0.6, style: .continuous)
                    .fill(LinearGradient(colors: [fill, fill.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                    .frame(width: max((width - height * 0.28) * level, height * 0.12))
                    .padding(height * 0.14)
                    .shadow(color: fill.opacity(0.6), radius: height * 0.15)
                if isConnected {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.62, weight: .black))
                        .foregroundStyle(appearance.text)
                        .shadow(color: .black.opacity(0.6), radius: height * 0.06)
                        .frame(width: width)
                }
            }
            .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: height * 0.06)
                .fill(appearance.text.opacity(0.75))
                .frame(width: height * 0.1, height: height * 0.36)
        }
    }
}
