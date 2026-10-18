import Foundation
import Testing
@testable import NotchCore

struct NowPlayingInfoTests {
    let start = Date(timeIntervalSince1970: 1_000)

    func info(playing: Bool, rate: Double = 1, elapsed: TimeInterval = 10, duration: TimeInterval? = 100) -> NowPlayingInfo {
        NowPlayingInfo(
            title: "t", artist: nil, album: nil, duration: duration, elapsed: elapsed,
            timestamp: start, playbackRate: rate, isPlaying: playing, appBundleID: "x", artworkData: nil
        )
    }

    @Test func positionAdvancesWhilePlaying() {
        #expect(info(playing: true).position(at: start.addingTimeInterval(5)) == 15)
    }

    @Test func positionHonorsPlaybackRate() {
        #expect(info(playing: true, rate: 2).position(at: start.addingTimeInterval(5)) == 20)
    }

    @Test func positionIsFrozenWhilePaused() {
        #expect(info(playing: false).position(at: start.addingTimeInterval(50)) == 10)
    }

    @Test func positionIsClampedToDuration() {
        #expect(info(playing: true).position(at: start.addingTimeInterval(500)) == 100)
    }

    @Test func progressIsNilWithoutDuration() {
        #expect(info(playing: true, duration: nil).progress(at: start) == nil)
        #expect(info(playing: false).progress(at: start) == 0.1)
    }
}
