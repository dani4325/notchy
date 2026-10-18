import SwiftUI

struct VisualizerView: View {
    let visualizer: AudioVisualizer?
    let height: CGFloat

    @Environment(\.themeAppearance) private var appearance

    private static let simulatedFrameRate: TimeInterval = 1.0 / 24

    var body: some View {
        Group {
            if let visualizer, visualizer.mode == .live {
                Bars(levels: visualizer.levels, height: height, appearance: appearance)
                    .animation(.linear(duration: 0.06), value: visualizer.levels)
            } else if visualizer != nil {
                TimelineView(.animation(minimumInterval: Self.simulatedFrameRate)) { context in
                    Bars(
                        levels: SimulatedSpectrum.levels(at: context.date.timeIntervalSinceReferenceDate, bandCount: SystemAudioTap.bandCount),
                        height: height,
                        appearance: appearance
                    )
                }
            } else {
                Bars(levels: SimulatedSpectrum.levels(at: 3.3, bandCount: SystemAudioTap.bandCount), height: height, appearance: appearance)
            }
        }
        .onAppear { visualizer?.acquire() }
        .onDisappear { visualizer?.release() }
        .accessibilityHidden(true)
    }
}

private struct Bars: View {
    let levels: [Float]
    let height: CGFloat
    let appearance: ThemeAppearance

    var body: some View {
        HStack(alignment: .bottom, spacing: height * 0.16) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(LinearGradient(colors: [appearance.accent, appearance.secondary], startPoint: .bottom, endPoint: .top))
                    .frame(width: height * 0.2, height: max(height * CGFloat(level), height * 0.14))
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}
