import AppKit
import ApplicationServices
import Observation

@MainActor
@Observable
public final class AccessibilityPermission {
    public private(set) var isTrusted = AXIsProcessTrusted()

    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var recheckTask: Task<Void, Never>?

    private static let recheckDelay: Duration = .milliseconds(500)

    public init() {}

    public func start() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRecheck() }
        }
    }

    public func stop() {
        observer.map(DistributedNotificationCenter.default().removeObserver)
        observer = nil
        recheckTask?.cancel()
    }

    public func request() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    private func scheduleRecheck() {
        recheckTask?.cancel()
        recheckTask = Task { [weak self] in
            try? await Task.sleep(for: Self.recheckDelay)
            guard !Task.isCancelled else { return }
            self?.isTrusted = AXIsProcessTrusted()
        }
    }
}
