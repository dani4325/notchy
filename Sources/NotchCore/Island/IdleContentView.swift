import SwiftUI

struct IdleContentView: View {
    let layout: IslandLayout

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        HStack(spacing: layout.columnGap) {
            if appearance.theme.decoration == .nixieTerminal {
                NixieReadoutView(text: Self.divergence, height: layout.artworkSide * 0.5, glow: appearance.secondary)
            } else {
                placeholder
            }
            details
        }
        .padding(.horizontal, layout.padding)
        .frame(width: layout.size.width, height: layout.bodyHeight)
    }

    private static let divergence = "1.048596"

    private var placeholder: some View {
            RoundedRectangle(cornerRadius: layout.artworkCorner, style: .continuous)
                .strokeBorder(
                    appearance.accent.opacity(0.6),
                    style: StrokeStyle(lineWidth: layout.unit * 0.04, dash: [layout.unit * 0.11, layout.unit * 0.11])
                )
                .frame(width: layout.artworkSide, height: layout.artworkSide)
                .overlay {
                    if let emblem = appearance.theme.emblem {
                        EmblemView(emblem: emblem, size: layout.artworkSide * 0.72, appearance: appearance)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: layout.artworkSide * 0.3, weight: .semibold))
                            .foregroundStyle(appearance.accent)
                    }
                }
    }

    private var details: some View {
            VStack(alignment: .leading, spacing: layout.textSpacing) {
                Text("NADA SONANDO")
                    .font(appearance.labelFont(layout.labelSize))
                    .tracking(appearance.theme.typography.labelTracking)
                    .foregroundStyle(appearance.accent)
                Text("Pon algo de música y aparecerá aquí")
                    .font(appearance.titleFont(layout.titleSize))
                    .foregroundStyle(appearance.text)
                    .lineLimit(2)
                Text(appearance.theme.name.lowercased())
                    .font(appearance.bodyFont(layout.timeSize))
                    .foregroundStyle(appearance.text.opacity(0.6))
                    .lineLimit(1)
            }
            .shadow(color: appearance.textShadow, radius: layout.unit * 0.08)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
