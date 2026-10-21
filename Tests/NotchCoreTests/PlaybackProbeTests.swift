import AppKit
import Testing
@testable import NotchCore

@MainActor
struct PlaybackProbeTests {
    @Test func aPlayingVideoReportsAPositionThatMoves() async throws {
        let probe = PlaybackProbe()
        let video = try await GIFTranscoder.transcode(GIFFixture.make(frames: 12))
        let view = MediaContainerView(probe: probe)
        view.frame = CGRect(x: 0, y: 0, width: 120, height: 120)

        view.configure(source: MediaSource(url: video, kind: .video), crop: .standard, isActive: true)
        await view.loadTask?.value
        let first = probe.snapshot()
        try await Task.sleep(for: .milliseconds(400))
        let second = probe.snapshot()

        #expect(first.keys.contains { $0.hasPrefix("video") })
        #expect(first != second)
    }

    @Test func aPausedGIFReportsTheSamePositionTwice() async throws {
        let probe = PlaybackProbe()
        let view = MediaContainerView(probe: probe)
        view.frame = CGRect(x: 0, y: 0, width: 120, height: 120)

        view.configure(source: MediaSource(url: try GIFFixture.make(), kind: .animatedImage), crop: .standard, isActive: false)
        await view.loadTask?.value
        let first = probe.snapshot()
        try await Task.sleep(for: .milliseconds(200))

        #expect(first.keys.contains { $0.hasPrefix("gif") })
        #expect(probe.snapshot() == first)
    }

    @Test func removedViewsStopReporting() async throws {
        let probe = PlaybackProbe()
        let view = MediaContainerView(probe: probe)

        view.configure(source: MediaSource(url: try GIFFixture.make(), kind: .animatedImage), crop: .standard, isActive: true)
        view.tearDown()

        #expect(probe.snapshot().isEmpty)
    }

    @Test func snapshotsAreWrittenAsOneSortedLine() {
        let probe = PlaybackProbe()
        let owner = NSObject()
        probe.register(owner, kind: "visualizer") { 42 }

        #expect(probe.line().hasSuffix(":42.000"))
        #expect(probe.line().hasPrefix("visualizer#"))
    }
}
