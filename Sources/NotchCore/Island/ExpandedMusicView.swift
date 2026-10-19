import SwiftUI

struct TransportActions {
    let previous: () -> Void
    let toggle: () -> Void
    let next: () -> Void

    static var inert: TransportActions { TransportActions(previous: {}, toggle: {}, next: {}) }
}

struct ExpandedMusicView: View {
    let layout: IslandLayout
    let info: NowPlayingInfo
    let artwork: NSImage?
    let appName: String?
    let controls: TransportActions
    var visualizer: AudioVisualizer?

    @Environment(\.themeAppearance) private var appearance
    @AppStorage(Preferences.Key.visualizer) private var showsVisualizer = true

    var body: some View {
        HStack(spacing: layout.columnGap) {
            ArtworkView(image: artwork, size: layout.artworkSide, cornerRadius: layout.artworkCorner)
                .shadow(color: appearance.accent.opacity(appearance.theme.effects.glow), radius: layout.unit * 0.35)

            VStack(alignment: .leading, spacing: layout.textSpacing) {
                HStack(alignment: .bottom) {
                    Text((appName ?? String(localized: "Ahora suena")).uppercased())
                        .font(appearance.labelFont(layout.labelSize))
                        .tracking(appearance.theme.typography.labelTracking)
                        .foregroundStyle(appearance.accentText)
                    Spacer(minLength: layout.textSpacing)
                    if showsVisualizer, info.isPlaying {
                        VisualizerView(visualizer: visualizer, height: layout.labelSize * IslandLayout.lineHeightFactor)
                    }
                }
                Text(info.title)
                    .font(appearance.titleFont(layout.titleSize))
                    .foregroundStyle(appearance.text)
                Text(info.artist ?? info.album ?? " ")
                    .font(appearance.bodyFont(layout.subtitleSize))
                    .foregroundStyle(appearance.text.opacity(0.78))
                Spacer(minLength: layout.progressGap)
                ProgressRow(layout: layout, info: info)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .shadow(color: appearance.textShadow, radius: layout.unit * 0.08)
            .frame(width: max(layout.textWidth, 0), height: layout.artworkSide, alignment: .leading)

            TransportControls(layout: layout, controls: controls, isPlaying: info.isPlaying)
        }
        .padding(.leading, layout.padding)
        .padding(.trailing, layout.trailingPadding)
        .frame(width: layout.size.width, height: layout.bodyHeight)
    }
}

private struct ProgressRow: View {
    let layout: IslandLayout
    let info: NowPlayingInfo

    @Environment(\.themeAppearance) private var appearance

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

        return VStack(spacing: layout.textSpacing) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(appearance.text.opacity(0.22))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [appearance.accentGraphic, appearance.secondaryGraphic],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(proxy.size.width * progress, layout.progressHeight))
                }
            }
            .frame(height: layout.progressHeight)

            if appearance.theme.decoration == .nixieTerminal {
                HStack {
                    NixieReadoutView(text: Self.format(position), height: layout.nixieHeight, glow: appearance.secondaryText)
                    Spacer(minLength: 0)
                    if let duration = info.duration {
                        NixieReadoutView(text: "-" + Self.format(max(duration - position, 0)), height: layout.nixieHeight, glow: appearance.secondaryText)
                    }
                }
            } else {
                HStack {
                    Text(Self.format(position))
                    Spacer(minLength: 0)
                    if let duration = info.duration {
                        Text("-" + Self.format(max(duration - position, 0)))
                    }
                }
                .font(appearance.numericFont(layout.timeSize))
                .foregroundStyle(appearance.text.opacity(0.72))
            }
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
    let layout: IslandLayout
    let controls: TransportActions
    let isPlaying: Bool

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        HStack(spacing: layout.controlSpacing) {
            Button(action: controls.previous) {
                Image(systemName: "backward.fill").font(.system(size: layout.skipIconSize))
            }
            .accessibilityLabel("Anterior")

            Button(action: controls.toggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: layout.playIconSize))
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(isPlaying ? Text("Pausa") : Text("Reproducir"))

            Button(action: controls.next) {
                Image(systemName: "forward.fill").font(.system(size: layout.skipIconSize))
            }
            .accessibilityLabel("Siguiente")
        }
        .buttonStyle(TransportButtonStyle(diameter: layout.controlDiameter, tint: appearance.text, pressed: appearance.accentGraphic))
        .shadow(color: appearance.textShadow, radius: layout.unit * 0.08)
        .frame(width: layout.controlsWidth)
    }
}

private struct TransportButtonStyle: ButtonStyle {
    let diameter: CGFloat
    let tint: Color
    let pressed: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? pressed : tint)
            .frame(width: diameter, height: diameter)
            .background(pressed.opacity(configuration.isPressed ? 0.2 : 0), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .contentShape(Circle())
    }
}
