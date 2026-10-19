import AppKit

@MainActor
public final class VolumeHUDCoordinator {
    public var onShow: ((VolumeReading, VolumeLimit?) -> Void)?

    private let volume = VolumeController()
    private let keys = MediaKeyTap()
    private var observers: [NSObjectProtocol] = []
    private var lastKeyPress: Date?

    private static let keyEchoWindow: TimeInterval = 0.5

    public init() {}

    public func start() {
        volume.onChange = { [weak self] reading in self?.volumeChanged(reading) }
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
        if Preferences.volumeHUD {
            keys.start()
        } else {
            keys.stop()
        }
    }

    private func keyPressed(_ key: MediaKey) -> Bool {
        guard let before = volume.current else { return false }
        volume.apply(key)
        guard key.isDown else { return true }
        lastKeyPress = Date()
        if let reading = volume.current {
            onShow?(reading, VolumeLimit.reached(before: before.isMuted ? 0 : before.level, after: reading.isMuted ? 0 : reading.level, kind: key.kind))
        }
        return true
    }

    private func volumeChanged(_ reading: VolumeReading) {
        if let lastKeyPress, Date().timeIntervalSince(lastKeyPress) < Self.keyEchoWindow {
            return
        }
        onShow?(reading, nil)
    }
}
