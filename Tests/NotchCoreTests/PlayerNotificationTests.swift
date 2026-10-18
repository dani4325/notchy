import Foundation
import Testing
@testable import NotchCore

struct PlayerNotificationTests {
    let now = Date(timeIntervalSince1970: 2_000)

    @Test func parsesSpotifyNotification() throws {
        let userInfo: [AnyHashable: Any] = [
            "Name": "Guren no Yumiya", "Artist": "Linked Horizon", "Album": "Single",
            "Duration": 312_000, "Playback Position": 42.5, "Player State": "Playing",
        ]

        let info = try #require(PlayerApp.spotify.info(from: userInfo, now: now))

        #expect(info.title == "Guren no Yumiya")
        #expect(info.duration == 312)
        #expect(info.elapsed == 42.5)
        #expect(info.isPlaying)
        #expect(info.appBundleID == "com.spotify.client")
    }

    @Test func parsesMusicNotificationWithoutPosition() throws {
        let userInfo: [AnyHashable: Any] = [
            "Name": "Skyclad", "Artist": "Itō", "Total Time": 200_000, "Player State": "Paused",
        ]

        let info = try #require(PlayerApp.music.info(from: userInfo, now: now))

        #expect(!info.isPlaying)
        #expect(info.duration == 200)
        #expect(info.elapsed == 0)
        #expect(info.appBundleID == "com.apple.Music")
    }

    @Test func stoppedPlayerProducesNoInfo() {
        let userInfo: [AnyHashable: Any] = ["Name": "x", "Player State": "Stopped"]

        #expect(PlayerApp.spotify.info(from: userInfo, now: now) == nil)
    }
}
