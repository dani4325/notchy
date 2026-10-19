import SwiftUI

struct VisualizerView: View {
    let visualizer: AudioVisualizer?
    let height: CGFloat

    @Environment(\.themeAppearance) private var appearance

    private static let simulatedFrameRate: TimeInterval = 1.0 / 24

    var body: some View {
        Group {
            if let visualizer, visualizer.mode == .live {
                SpectrumBars(source: visualizer, color: appearance.accentBarColor, height: height)
            } else if visualizer != nil {
                TimelineView(.animation(minimumInterval: Self.simulatedFrameRate)) { context in
                    SpectrumBars(
                        levels: SimulatedSpectrum.levels(at: context.date.timeIntervalSinceReferenceDate, bandCount: SystemAudioTap.bandCount),
                        color: appearance.accentBarColor,
                        height: height
                    )
                }
            } else {
                SpectrumBars(levels: SimulatedSpectrum.levels(at: 3.3, bandCount: SystemAudioTap.bandCount), color: appearance.accentBarColor, height: height)
            }
        }
        .onAppear { visualizer?.acquire() }
        .onDisappear { visualizer?.release() }
        .accessibilityHidden(true)
    }
}
