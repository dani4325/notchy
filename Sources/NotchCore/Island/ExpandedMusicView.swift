import SwiftUI

struct ExpandedMusicView: View {
    let nowPlaying: NowPlayingStore
    let info: NowPlayingInfo

    var body: some View {
        HStack(spacing: 16) {
            ArtworkView(image: nowPlaying.artwork, size: 86, cornerRadius: 16)
                .shadow(color: NotchyStyle.accent.opacity(0.25), radius: 12, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text((nowPlaying.appName ?? "Ahora suena").uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(NotchyStyle.accent)
                Text(info.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(info.artist ?? info.album ?? " ")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 6)
                ProgressRow(info: info)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            TransportControls(nowPlaying: nowPlaying, isPlaying: info.isPlaying)
        }
        .frame(height: 86)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }
}

private struct ProgressRow: View {
    let info: NowPlayingInfo

    private static let tick: TimeInterval = 0.5

    var body: some View {
        if info.isPlaying {
            TimelineView(.periodic(from: .now, by: Self.tick)) { context in
                content(at: context.date)
                    .animation(.linear(duration: Self.tick), value: context.date)
            }
        } else {
            content(at: Date())
        }
    }

    private func content(at date: Date) -> some View {
        let position = info.position(at: date)
        let progress = info.progress(at: date) ?? 0

        return VStack(spacing: 4) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14))
                    Capsule()
                        .fill(NotchyStyle.accent)
                        .frame(width: max(proxy.size.width * progress, 4))
                }
            }
            .frame(height: 4)

            HStack {
                Text(Self.format(position))
                Spacer()
                if let duration = info.duration {
                    Text("-" + Self.format(max(duration - position, 0)))
                }
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.45))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Self.format(position))
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct TransportControls: View {
    let nowPlaying: NowPlayingStore
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button(action: nowPlaying.previousTrack) {
                Image(systemName: "backward.fill").font(.system(size: 15))
            }
            .accessibilityLabel("Anterior")

            Button(action: nowPlaying.togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(isPlaying ? "Pausa" : "Reproducir")

            Button(action: nowPlaying.nextTrack) {
                Image(systemName: "forward.fill").font(.system(size: 15))
            }
            .accessibilityLabel("Siguiente")
        }
        .buttonStyle(TransportButtonStyle())
    }
}

private struct TransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.7 : 1))
            .frame(width: 38, height: 38)
            .background(.white.opacity(configuration.isPressed ? 0.14 : 0), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .contentShape(Circle())
    }
}
