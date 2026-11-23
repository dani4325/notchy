import SwiftUI

struct IslandView: View {
    let model: IslandModel
    let nowPlaying: NowPlayingStore
    let companion: CompanionStore
    let themes: ThemeStore
    let visualizer: AudioVisualizer
    let shelf: ShelfStore
    let togglePage: () -> Void
    let stepVolume: (MediaKeyKind) -> Void

    @AppStorage(Preferences.Key.shelf) private var shelfEnabled = true

    @AppStorage(Preferences.Key.showCalibrationOutline) private var showOutline = false

    var body: some View {
        let appearance = ThemeAppearance.resolve(themes.activeTheme, in: themes)
        let policy = MotionPolicy(reduceMotion: model.reduceMotion, openAnimation: model.openAnimation)
        let size = model.currentSize

        ZStack(alignment: .top) {
            IslandSurface(model: model, appearance: appearance, showOutline: showOutline)
                .frame(width: size.width, height: size.height)

            Group {
                switch model.state {
                case .expanded:
                    expandedContent
                        .frame(width: size.width, height: model.layout.bodyHeight)
                        .overlay(alignment: .topTrailing) {
                            if shelfEnabled, model.activity == nil {
                                PageToggleButton(page: model.page, count: shelf.items.count, layout: model.layout, action: togglePage)
                                    .padding(.top, model.layout.padding * 0.18)
                                    .padding(.trailing, model.layout.padding * 0.55)
                            }
                        }
                        .padding(.top, model.layout.stem.height)
                        .frame(width: size.width, height: size.height, alignment: .top)
                        .transition(contentTransition(policy))
                case .compact:
                    CompactWingsView(nowPlaying: nowPlaying, companion: companion, wing: model.compactWing, height: size.height, volume: compactVolume)
                        .frame(width: size.width, height: size.height)
                        .transition(.opacity.animation(policy.contentAnimation))
                case .collapsed:
                    EmptyView()
            }
            }
            .modifier(SignatureOpening(
                kind: model.openAnimation,
                trigger: model.openCount,
                isEnabled: policy.playsSignatureOpening,
                layout: model.layout,
                appearance: appearance
            ))
        }
        .coordinateSpace(.named(LegibilityMark.space))
        .onPreferenceChange(LegibilityMarksKey.self) { marks in
            if model.legibilityMarks != marks { model.legibilityMarks = marks }
        }
        .modifier(NotchBounce(nudge: volumeNudge, isEnabled: !policy.reduceMotion))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.themeAppearance, appearance)
    }

    private var volumeNudge: VolumeNudge? {
        if case .volume(_, let nudge) = model.activity { return nudge }
        return nil
    }

    private var compactVolume: VolumeReading? {
        if case .volume(let reading, _) = model.activity { return reading }
        return nil
    }

    @ViewBuilder
    private var expandedContent: some View {
        if case .power(let event) = model.activity {
            ChargingView(layout: model.layout, event: event)
        } else if case .volume(let reading, let nudge) = model.activity {
            VolumeHUDView(layout: model.layout, reading: reading, nudge: nudge, step: stepVolume)
        } else if model.activity == .greeting {
            GreetingView(layout: model.layout)
        } else if shelfEnabled, model.page == .shelf {
            ShelfView(layout: model.layout, shelf: shelf, isDropTargeted: model.isDropTargeted)
        } else if let info = nowPlaying.info {
            ExpandedMusicView(
                layout: model.layout,
                info: info,
                artwork: nowPlaying.artwork,
                appName: nowPlaying.appName,
                controls: TransportActions(
                    previous: nowPlaying.previousTrack,
                    toggle: nowPlaying.togglePlayPause,
                    next: nowPlaying.nextTrack
                ),
                visualizer: visualizer
            )
        } else {
            IdleContentView(layout: model.layout)
        }
    }

    private func contentTransition(_ policy: MotionPolicy) -> AnyTransition {
        guard policy.animatesShape else {
            return .asymmetric(
                insertion: .opacity.animation(policy.contentAnimation),
                removal: .identity
            )
        }
        return .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: policy.contentScale, anchor: .top))
                .animation(policy.contentAnimation.delay(0.06)),
            removal: .opacity.animation(.easeOut(duration: 0.12))
        )
    }
}
