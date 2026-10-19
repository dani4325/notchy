import SwiftUI

struct CompactWingsView: View {
    @Environment(\.themeAppearance) private var appearance

    let nowPlaying: NowPlayingStore
    let companion: CompanionStore
    let wing: CGFloat
    let height: CGFloat
    var volume: VolumeReading?

    private var mediaSize: CGFloat { height - 10 }

    private static let compactBarHeight: CGFloat = 3
    private static let compactBarShare: CGFloat = 0.6

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
        .accessibilityLabel(nowPlaying.info.map { Text("Sonando: \($0.title)") } ?? Text("Nada sonando"))
    }

    @ViewBuilder
    private var leftWing: some View {
        if let volume {
            VolumeSymbol(reading: volume, size: mediaSize * 0.5)
                .foregroundStyle(appearance.text)
        } else if let info = nowPlaying.info {
            ArtworkView(image: nowPlaying.artwork, size: mediaSize, cornerRadius: 7)
                .opacity(info.isPlaying ? 1 : 0.45)
                .overlay {
                    if !info.isPlaying {
                        Image(systemName: "pause.fill")
                            .font(.system(size: mediaSize * 0.42, weight: .heavy))
                            .foregroundStyle(appearance.text)
                            .shadow(color: .black.opacity(0.6), radius: 3)
                    }
                }
        } else {
            Image(systemName: "music.note")
                .font(.system(size: mediaSize * 0.45, weight: .semibold))
                .foregroundStyle(appearance.secondaryTextColor)
        }
    }

    @ViewBuilder
    private var rightWing: some View {
        if let volume {
            LevelBar(
                fraction: Double(volume.isMuted ? 0 : volume.level),
                fill: appearance.accentBarColor, track: appearance.barTrackColor, height: Self.compactBarHeight
            )
            .frame(width: wing * Self.compactBarShare, height: Self.compactBarHeight)
        } else if let source = companion.source {
            MediaView(source: source, isActive: nowPlaying.isPlaying)
                .frame(width: mediaSize, height: mediaSize)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}
