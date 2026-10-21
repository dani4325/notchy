import AppKit
import os

@MainActor
public final class PlaybackProbe {
    public static let shared = PlaybackProbe()
    public static let requestName = Notification.Name("com.danirubio.notchy.playback-probe")

    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "probe")
    private static let positionFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(3)).grouping(.never).locale(Locale(identifier: "en_US_POSIX"))

    private struct Reporter {
        let kind: String
        let position: () -> Double?
    }

    private var reporters: [ObjectIdentifier: Reporter] = [:]
    private var observer: NSObjectProtocol?

    init() {}

    public func start() {
        observer = DistributedNotificationCenter.default().addObserver(forName: Self.requestName, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.log() }
        }
    }

    func register(_ owner: AnyObject, kind: String, position: @escaping () -> Double?) {
        reporters[ObjectIdentifier(owner)] = Reporter(kind: kind, position: position)
    }

    func unregister(_ owner: AnyObject) {
        reporters[ObjectIdentifier(owner)] = nil
    }

    func snapshot() -> [String: Double] {
        var values: [String: Double] = [:]
        for (id, reporter) in reporters {
            guard let position = reporter.position() else { continue }
            values[reporter.kind + "#" + String(UInt(bitPattern: id.hashValue) % 10_000)] = position
        }
        return values
    }

    func line() -> String {
        snapshot().sorted { $0.key < $1.key }.map { $0.key + ":" + $0.value.formatted(Self.positionFormat) }.joined(separator: " ")
    }

    private func log() {
        Self.logger.notice("playback \(self.line(), privacy: .public)")
    }
}
