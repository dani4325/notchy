import Foundation
import Observation

@MainActor
@Observable
public final class WingsVisibility {
    public private(set) var isVisible = false

    @ObservationIgnored private let nowPlaying: NowPlayingStore
    @ObservationIgnored private var mode = Preferences.wingsMode
    @ObservationIgnored private var phase = WingsPhase.idle
    @ObservationIgnored private var hideTimer: Task<Void, Never>?
    @ObservationIgnored private var defaultsObserver: NSObjectProtocol?
    @ObservationIgnored private var isRunning = false

    public init(nowPlaying: NowPlayingStore) {
        self.nowPlaying = nowPlaying
    }

    public func start() {
        isRunning = true
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.preferencesChanged() }
        }
        observePlayback()
        evaluate()
    }

    public func stop() {
        isRunning = false
        hideTimer?.cancel()
        defaultsObserver.map(NotificationCenter.default.removeObserver)
        defaultsObserver = nil
    }

    private func preferencesChanged() {
        let newMode = Preferences.wingsMode
        guard newMode != mode else { return }
        mode = newMode
        evaluate()
    }

    private func observePlayback() {
        withObservationTracking {
            _ = nowPlaying.isPlaying
            _ = nowPlaying.info == nil
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.observePlayback()
                self.evaluate()
            }
        }
    }

    private func evaluate() {
        let now = Date()
        phase = WingsPhase.next(
            after: phase, isPlaying: nowPlaying.isPlaying, hasMedia: nowPlaying.info != nil, now: now
        )
        let visible = WingsPolicy.isVisible(mode: mode, phase: phase, now: now)
        if visible != isVisible {
            isVisible = visible
        }
        scheduleHide(now: now)
    }

    private func scheduleHide(now: Date) {
        hideTimer?.cancel()
        hideTimer = nil
        guard let deadline = WingsPolicy.hideDeadline(mode: mode, phase: phase), deadline > now else { return }
        hideTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(deadline.timeIntervalSince(now)))
            guard !Task.isCancelled else { return }
            self?.evaluate()
        }
    }
}
