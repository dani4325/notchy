import Foundation
import Testing
@testable import NotchCore

struct WingsPolicyTests {
    let now = Date(timeIntervalSince1970: 10_000)

    @Test func alwaysModeShowsWingsInEveryPhase() {
        for phase in [WingsPhase.idle, .playing, .paused(since: now)] {
            #expect(WingsPolicy.isVisible(mode: .always, phase: phase, now: now))
        }
    }

    @Test func neverModeHidesWingsInEveryPhase() {
        for phase in [WingsPhase.idle, .playing, .paused(since: now)] {
            #expect(!WingsPolicy.isVisible(mode: .never, phase: phase, now: now))
        }
    }

    @Test func withMusicShowsWhilePlayingAndHidesWhenIdle() {
        #expect(WingsPolicy.isVisible(mode: .withMusic, phase: .playing, now: now))
        #expect(!WingsPolicy.isVisible(mode: .withMusic, phase: .idle, now: now))
    }

    @Test func withMusicKeepsWingsForOneMinuteAfterPausing() {
        let pausedAt = now
        let phase = WingsPhase.paused(since: pausedAt)

        #expect(WingsPolicy.isVisible(mode: .withMusic, phase: phase, now: pausedAt.addingTimeInterval(59)))
        #expect(!WingsPolicy.isVisible(mode: .withMusic, phase: phase, now: pausedAt.addingTimeInterval(60)))
    }

    @Test func hideDeadlineOnlyExistsForPausedWithMusic() {
        #expect(WingsPolicy.hideDeadline(mode: .withMusic, phase: .paused(since: now)) == now.addingTimeInterval(60))
        #expect(WingsPolicy.hideDeadline(mode: .withMusic, phase: .playing) == nil)
        #expect(WingsPolicy.hideDeadline(mode: .always, phase: .paused(since: now)) == nil)
        #expect(WingsPolicy.hideDeadline(mode: .never, phase: .paused(since: now)) == nil)
    }

    @Test func phaseTracksTransitionFromPlayingToPaused() {
        #expect(WingsPhase.next(after: .idle, isPlaying: true, hasMedia: true, now: now) == .playing)
        #expect(WingsPhase.next(after: .playing, isPlaying: false, hasMedia: true, now: now) == .paused(since: now))
        let paused = WingsPhase.paused(since: now)
        #expect(WingsPhase.next(after: paused, isPlaying: false, hasMedia: true, now: now.addingTimeInterval(5)) == paused)
    }

    @Test func phaseIsIdleWhenNothingPlayedOrMediaDisappears() {
        #expect(WingsPhase.next(after: .idle, isPlaying: false, hasMedia: true, now: now) == .idle)
        #expect(WingsPhase.next(after: .paused(since: now), isPlaying: false, hasMedia: false, now: now) == .idle)
        #expect(WingsPhase.next(after: .playing, isPlaying: false, hasMedia: false, now: now) == .idle)
    }
}
