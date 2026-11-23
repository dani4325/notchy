import Testing
@testable import NotchCore

@MainActor
struct VisualizerSubscriptionTests {
    @Test func subscribersReceiveLevelsUntilTheyStopObserving() {
        let visualizer = AudioVisualizer()
        var received: [[Float]] = []
        let id = visualizer.observeLevels { received.append($0) }

        visualizer.release()
        #expect(received.count == 1)
        #expect(received.last?.allSatisfy { $0 == 0 } == true)

        visualizer.stopObservingLevels(id)
        visualizer.release()
        #expect(received.count == 1)
    }

    @Test func spectrumBarsSwitchesSourceCleanly() {
        let first = AudioVisualizer()
        let second = AudioVisualizer()
        let view = SpectrumBarsView(frame: .init(x: 0, y: 0, width: 60, height: 20))
        view.animated = false
        view.observe(first)
        view.observe(second)
        first.release()
        second.release()
        view.observe(nil)
        second.release()
    }

    @Test func systemAudioTapStopIsIdempotent() {
        let tap = SystemAudioTap()
        tap.stop()
        tap.stop()
    }
}
