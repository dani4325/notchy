import AppKit
import Foundation
import Observation
import os

@MainActor
@Observable
public final class AudioVisualizer {
    public enum Mode: Equatable {
        case live
        case simulated
    }

    @ObservationIgnored public private(set) var levels = [Float](repeating: 0, count: SystemAudioTap.bandCount)
    @ObservationIgnored private var listeners: [UUID: ([Float]) -> Void] = [:]
    public private(set) var mode = Mode.live

    @ObservationIgnored private var tap: SystemAudioTap?
    @ObservationIgnored private var viewers = 0
    @ObservationIgnored private var silentSince: Date?
    @ObservationIgnored private var framesReceived = 0

    private static let silenceFallback: TimeInterval = 3
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "visualizer")

    public init() {}

    private static let permissionProbeDuration: Duration = .milliseconds(1500)

    public static func requestPermission() {
        let probe = SystemAudioTap()
        do {
            try probe.start()
        } catch {
            logger.error("permission probe failed: \(String(describing: error), privacy: .public)")
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: permissionProbeDuration)
            probe.stop()
        }
    }

    func acquire() {
        viewers += 1
        guard viewers == 1, Preferences.visualizer else { return }
        mode = .live
        silentSince = nil
        startTap()
    }

    func release() {
        viewers = max(viewers - 1, 0)
        guard viewers == 0 else { return }
        stopTap()
        levels = levels.map { _ in 0 }
        publish()
    }

    private func startTap() {
        let newTap = SystemAudioTap()
        newTap.onLevels = { [weak self] levels, isSilent in
            Task { @MainActor [weak self] in self?.received(levels, isSilent: isSilent) }
        }
        do {
            try newTap.start()
            tap = newTap
            silentSince = nil
            PlaybackProbe.shared.register(self, kind: "visualizer") { [weak self] in
                self.map { Double($0.framesReceived) }
            }
        } catch {
            Self.logger.error("audio tap unavailable: \(String(describing: error), privacy: .public)")
            mode = .simulated
        }
    }

    private func stopTap() {
        tap?.stop()
        tap = nil
        PlaybackProbe.shared.unregister(self)
    }

    private func received(_ newLevels: [Float], isSilent: Bool) {
        guard tap != nil else { return }
        if isSilent {
            let start = silentSince ?? Date()
            silentSince = start
            if Date().timeIntervalSince(start) > Self.silenceFallback {
                stopTap()
                mode = .simulated
            }
        } else {
            silentSince = nil
            confirmCapture()
        }
        framesReceived += 1
        levels = SpectrumAnalyzer.smooth(previous: levels, next: newLevels)
        publish()
    }

    public static let captureSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!

    public static func openCaptureSettings() {
        NSWorkspace.shared.open(captureSettingsURL)
    }

    private func confirmCapture() {
        guard !UserDefaults.standard.bool(forKey: Preferences.Key.audioCaptureConfirmed) else { return }
        UserDefaults.standard.set(true, forKey: Preferences.Key.audioCaptureConfirmed)
    }

    func observeLevels(_ handler: @escaping ([Float]) -> Void) -> UUID {
        let id = UUID()
        listeners[id] = handler
        return id
    }

    func stopObservingLevels(_ id: UUID) {
        listeners[id] = nil
    }

    private func publish() {
        listeners.values.forEach { $0(levels) }
    }
}
