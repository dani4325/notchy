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
        PanelRow(layout: layout, subtitle: Text(verbatim: info.artist ?? info.album ?? " ")) {
            ArtworkView(image: artwork, size: layout.artworkSide, cornerRadius: layout.artworkCorner)
                .shadow(color: appearance.accent.opacity(appearance.theme.effects.glow), radius: layout.unit * 0.35)
                .overlay(alignment: .bottomTrailing) { sourceBadge }
        } title: {
            Text(verbatim: info.title)
        } accessory: {
            if showsVisualizer, info.isPlaying {
                VisualizerView(visualizer: visualizer, height: layout.labelSize * IslandLayout.lineHeightFactor)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
            }
        } bar: {
            ProgressRow(layout: layout, info: info)
        } trailing: {
            TransportControls(layout: layout, controls: controls, isPlaying: info.isPlaying)
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        if let icon = AppIconCache.icon(forBundleID: info.appBundleID) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: layout.artworkSide * Self.badgeRatio, height: layout.artworkSide * Self.badgeRatio)
                .offset(x: layout.artworkSide * Self.badgeOffsetRatio, y: layout.artworkSide * Self.badgeOffsetRatio)
                .accessibilityLabel(Text(verbatim: appName ?? ""))
        }
    }

    private static let badgeRatio: CGFloat = 0.34
    private static let badgeOffsetRatio: CGFloat = 0.08
}

private struct ProgressRow: View {
    let layout: IslandLayout
    let info: NowPlayingInfo

    @Environment(\.themeAppearance) private var appearance

    private static let tick: TimeInterval = 1

    var body: some View {
        if info.isPlaying {
            TimelineView(.periodic(from: .now, by: Self.tick)) { context in
                content(at: context.date, barTarget: context.date.addingTimeInterval(Self.tick), transition: Self.tick)
            }
        } else {
            content(at: Date(), barTarget: Date(), transition: 0)
        }
    }

    private func content(at date: Date, barTarget: Date, transition: TimeInterval) -> some View {
        let position = info.position(at: date)

        return VStack(spacing: layout.textSpacing) {
            LevelBar(
                fraction: info.progress(at: barTarget) ?? 0,
                fill: appearance.accentBarColor,
                track: appearance.barTrackColor,
                height: layout.progressHeight,
                transition: transition
            )
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
                .foregroundStyle(appearance.secondaryTextColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progreso")
        .accessibilityValue(accessibleProgress(at: position))
    }

    private func accessibleProgress(at position: TimeInterval) -> Text {
        let elapsed = Self.format(position)
        guard let duration = info.duration else { return Text(verbatim: elapsed) }
        let total = Self.format(duration)
        return Text("\(elapsed) de \(total)")
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
        .buttonStyle(TransportButtonStyle(diameter: layout.controlDiameter, spacing: layout.controlSpacing, tint: appearance.text, pressed: appearance.accentGraphic))
        .frame(width: layout.controlsWidth)
    }
}

struct TransportButtonStyle: ButtonStyle {
    static let minimumTarget: CGFloat = 44

    let diameter: CGFloat
    var spacing: CGFloat = 0
    let tint: Color
    let pressed: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var targetWidth: CGFloat { max(diameter, min(Self.minimumTarget, diameter + spacing)) }
    private var targetHeight: CGFloat { max(diameter, Self.minimumTarget) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? pressed : tint)
            .frame(width: diameter, height: diameter)
            .background(pressed.opacity(configuration.isPressed ? 0.2 : 0), in: Circle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.86 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2), value: configuration.isPressed)
            .frame(width: targetWidth, height: targetHeight)
            .contentShape(Rectangle())
            .padding(.horizontal, (diameter - targetWidth) / 2)
            .padding(.vertical, (diameter - targetHeight) / 2)
    }
}
