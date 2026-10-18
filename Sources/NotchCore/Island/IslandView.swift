import SwiftUI

struct IslandView: View {
    let model: IslandModel
    let nowPlaying: NowPlayingStore
    let companion: CompanionStore

    @AppStorage(Preferences.Key.showCalibrationOutline) private var showOutline = false

    var body: some View {
        let policy = MotionPolicy(reduceMotion: model.reduceMotion)
        let size = model.currentSize

        ZStack(alignment: .top) {
            shape
                .fill(.black)
                .overlay {
                    if showOutline {
                        shape.stroke(NotchyStyle.accent, lineWidth: 1)
                    }
                }
                .frame(width: size.width, height: size.height)

            switch model.state {
            case .expanded:
                expandedContent
                    .padding(.top, model.contentTopInset)
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
    }

    @ViewBuilder
    private var expandedContent: some View {
        if let info = nowPlaying.info {
            ExpandedMusicView(nowPlaying: nowPlaying, info: info)
        } else {
            IdleContentView()
        }
    }

    private var shape: IslandShape {
        IslandShape(
            stemWidth: model.collapsedSize.width,
            stemHeight: model.stemHeight,
            topRadius: model.topRadius,
            bodyTopRadius: model.bodyTopRadius,
            bottomRadius: model.bottomRadius,
            junctionRadius: model.junctionRadius
        )
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
