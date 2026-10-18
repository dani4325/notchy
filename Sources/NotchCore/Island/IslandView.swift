import SwiftUI

struct IslandView: View {
    let model: IslandModel
    let nowPlaying: NowPlayingStore
    let companion: CompanionStore
    let themes: ThemeStore

    @AppStorage(Preferences.Key.showCalibrationOutline) private var showOutline = false

    var body: some View {
        let appearance = ThemeAppearance.resolve(themes.activeTheme, in: themes)
        let policy = MotionPolicy(reduceMotion: model.reduceMotion, openAnimation: model.openAnimation)
        let size = model.currentSize

        ZStack(alignment: .top) {
            IslandSurface(model: model, appearance: appearance, showOutline: showOutline)
                .frame(width: size.width, height: size.height)

            switch model.state {
            case .expanded:
                expandedContent
                    .frame(width: size.width, height: model.layout.bodyHeight)
                    .padding(.top, model.layout.stem.height)
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .transition(contentTransition(policy))
            case .compact:
                CompactWingsView(nowPlaying: nowPlaying, companion: companion, wing: model.compactWing, height: size.height)
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity.animation(policy.contentAnimation))
            case .collapsed:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.themeAppearance, appearance)
    }

    @ViewBuilder
    private var expandedContent: some View {
        if let info = nowPlaying.info {
            ExpandedMusicView(
                layout: model.layout,
                info: info,
                artwork: nowPlaying.artwork,
                appName: nowPlaying.appName,
                controls: TransportActions(
                    previous: nowPlaying.previousTrack,
                    toggle: nowPlaying.togglePlayPause,
                    next: nowPlaying.nextTrack
                )
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
