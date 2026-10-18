import SwiftUI

struct CompactWingsView: View {
    let nowPlaying: NowPlayingStore
    let companion: CompanionStore
    let wing: CGFloat
    let height: CGFloat

    private var mediaSize: CGFloat { height - 10 }

    var body: some View {
        HStack(spacing: 0) {
            leftWing
                .frame(width: wing)
            Spacer(minLength: 0)
            rightWing
                .frame(width: wing)
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nowPlaying.info.map { "Sonando: \($0.title)" } ?? "Nada sonando")
    }

    @ViewBuilder
    private var leftWing: some View {
        if let info = nowPlaying.info {
            ArtworkView(image: nowPlaying.artwork, size: mediaSize, cornerRadius: 7)
                .opacity(info.isPlaying ? 1 : 0.45)
                .overlay {
                    if !info.isPlaying {
                        Image(systemName: "pause.fill")
                            .font(.system(size: mediaSize * 0.42, weight: .heavy))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 3)
                    }
                }
        } else {
            Image(systemName: "music.note")
                .font(.system(size: mediaSize * 0.45, weight: .semibold))
                .foregroundStyle(.white.opacity(0.22))
        }
    }

    @ViewBuilder
    private var rightWing: some View {
        if let image = companion.image {
            CompanionMediaView(image: image, isAnimating: nowPlaying.isPlaying)
                .frame(width: mediaSize, height: mediaSize)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Image(systemName: "sparkle")
                .font(.system(size: mediaSize * 0.5, weight: .bold))
                .foregroundStyle(NotchyStyle.accent.opacity(nowPlaying.isPlaying ? 1 : 0.45))
        }
    }
}
