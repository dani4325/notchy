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
}
