import SwiftUI

struct GreetingView: View {
    let layout: IslandLayout

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        HStack(spacing: layout.columnGap) {
            Group {
                if let emblem = appearance.theme.emblem {
                    EmblemView(emblem: emblem, size: layout.artworkSide * 0.8, appearance: appearance)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: layout.artworkSide * 0.4, weight: .semibold))
                        .foregroundStyle(appearance.accentGraphic)
                }
            }
            .frame(width: layout.artworkSide, height: layout.artworkSide)

            VStack(alignment: .leading, spacing: layout.textSpacing) {
                Text("HOLA")
                    .font(appearance.labelFont(layout.labelSize))
                    .tracking(appearance.theme.typography.labelTracking)
                    .foregroundStyle(appearance.accentText)
                Text("Esto es Notchy")
                    .font(appearance.titleFont(layout.titleSize * 1.3))
                    .foregroundStyle(appearance.text)
                Text("Pasa el ratón por el notch cuando quieras")
                    .font(appearance.bodyFont(layout.subtitleSize))
                    .foregroundStyle(appearance.text.opacity(0.7))
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, layout.padding)
        .frame(width: layout.size.width, height: layout.bodyHeight)
    }
}
