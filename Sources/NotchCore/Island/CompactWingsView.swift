import SwiftUI

struct CompactWingsView: View {
    @Environment(\.themeAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let nowPlaying: NowPlayingStore
    let companion: CompanionStore
    let wing: CGFloat
    let height: CGFloat
    var volume: VolumeReading?

    private var mediaSize: CGFloat { IslandLayout.wingMediaSide(height: height) }
    private var corner: CGFloat { IslandLayout.wingCorner(height: height) }
    private var barHeight: CGFloat { IslandLayout.wingBarHeight(height: height) }

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
        .accessibilityLabel(nowPlaying.info.map { $0.isPlaying ? Text("Sonando: \($0.title)") : Text("En pausa: \($0.title)") } ?? Text("Nada sonando"))
    }

    @ViewBuilder
    private var leftWing: some View {
        if let volume {
            VolumeSymbol(reading: volume, size: mediaSize * 0.5)
                .foregroundStyle(appearance.text)
        } else if let info = nowPlaying.info {
            ArtworkView(image: nowPlaying.artwork, size: mediaSize, cornerRadius: corner)
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
                fill: appearance.accentBarColor, track: appearance.barTrackColor, height: barHeight
            )
            .frame(width: wing * IslandLayout.wingBarShare, height: barHeight)
        } else if let source = companion.source {
            MediaView(source: source, isActive: nowPlaying.isPlaying && !reduceMotion)
                .frame(width: mediaSize, height: mediaSize)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
    }
}
