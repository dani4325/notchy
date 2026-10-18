import SwiftUI

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(appearance.text.opacity(0.08))
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                } else if let emblem = appearance.theme.emblem {
                    EmblemView(emblem: emblem, size: size * 0.78, appearance: appearance)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.32, weight: .semibold))
                        .foregroundStyle(appearance.accent)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
