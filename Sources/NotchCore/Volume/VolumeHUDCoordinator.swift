import AppKit
import os

@MainActor
public final class VolumeHUDCoordinator {
    public var onShow: ((VolumeReading, VolumeNudge.Direction?, VolumeLimit?) -> Void)?

    private let volume = VolumeController()
    private let keys = MediaKeyTap()
    private var observers: [NSObjectProtocol] = []
    private var lastKeyPress: Date?
    private var lastReading: VolumeReading?
    private var interceptionGaveUp = false
    private var lastPressWentToMacOS = false

    private static let keyEchoWindow: TimeInterval = 0.5
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "volume")

    public init() {}

    public func start() {
        volume.onChange = { [weak self] reading in self?.volumeChanged(reading) }
        volume.onOutputChange = { [weak self] in
            self?.interceptionGaveUp = false
            self?.syncKeyTap()
        }
        volume.start()
        keys.onKey = { [weak self] key in self?.keyPressed(key) ?? false }
        observers = [
            NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.syncKeyTap() }
            },
            DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.syncKeyTap() }
            },
        ]
        syncKeyTap()
    }

    public func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0); DistributedNotificationCenter.default().removeObserver($0) }
        observers = []
        keys.stop()
        volume.stop()
    }

    private func syncKeyTap() {
        if Preferences.volumeHUD, AXIsProcessTrusted(), !interceptionGaveUp {
            keys.start()
        } else {
            keys.stop()
        }
    }

    public func step(_ kind: MediaKeyKind) {
        _ = keyPressed(MediaKey(kind: kind, isDown: true, isRepeat: false))
    }

    private func keyPressed(_ key: MediaKey) -> Bool {
        guard key.isDown else { return !lastPressWentToMacOS }
        lastPressWentToMacOS = true
        guard !FullScreenDetector.isActive(), let before = volume.current else { return false }
        volume.apply(key)
        guard let reading = volume.current else { return false }
        if !key.isRepeat, InterceptionSafeguard.interceptionFailed(before: before, after: reading, key: key.kind) {
            Self.logger.error("volume did not change after a key press; leaving keys to macOS")
            interceptionGaveUp = true
            syncKeyTap()
            return false
        }
        lastPressWentToMacOS = false
        lastKeyPress = Date()
        let limit = VolumeLimit.reached(before: before.isMuted ? 0 : before.level, after: reading.isMuted ? 0 : reading.level, kind: key.kind)
        onShow?(reading, VolumeNudge.Direction.of(from: before, to: reading, key: key.kind), limit)
        lastReading = reading
        return true
    }

    private func volumeChanged(_ reading: VolumeReading) {
        defer { lastReading = reading }
        if let lastKeyPress, Date().timeIntervalSince(lastKeyPress) < Self.keyEchoWindow {
            return
        }
        guard !FullScreenDetector.isActive() else { return }
        onShow?(reading, VolumeNudge.Direction.of(from: lastReading, to: reading, key: nil), nil)
    }
}
