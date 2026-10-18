import SwiftUI

struct IslandView: View {
    let model: IslandModel

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

            if model.isExpanded {
                IdleContentView()
                    .padding(.top, model.contentTopInset)
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .transition(contentTransition(policy))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: model.topRadius,
            bottomLeadingRadius: model.bottomRadius,
            bottomTrailingRadius: model.bottomRadius,
            topTrailingRadius: model.topRadius,
            style: .continuous
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
