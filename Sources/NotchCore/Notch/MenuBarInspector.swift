import AppKit
import ApplicationServices
import os

@MainActor
final class MenuBarInspector {
    private nonisolated static let logger = Logger(subsystem: "com.danirubio.notchy", category: "menubar")
    private static let settleDelay: Duration = .milliseconds(1200)
    private nonisolated static let messagingTimeout: Float = 0.5

    var onCollisionChange: ((Bool) -> Void)?
    var wingZones: () -> [CGRect] = { [] }

    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var settleTask: Task<Void, Never>?
    private var lastResult = false

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        observers = [
            (workspace, workspace.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.inspectNowAndAfterSettling() }
            }),
            (distributed, distributed.addObserver(
                forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.inspectNowAndAfterSettling() }
            }),
        ]
        inspect()
    }

    func stop() {
        observers.forEach { center, token in center.removeObserver(token) }
        observers = []
        settleTask?.cancel()
    }

    func inspect() {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              let primaryHeight = NSScreen.screens.first?.frame.maxY
        else {
            report(false)
            return
        }
        let pid = app.processIdentifier
        let zones = wingZones()
        Task.detached(priority: .utility) {
            let items = Self.menuItemFrames(pid: pid).map {
                MenuCollision.cocoaFrame(fromAccessibility: $0, primaryScreenHeight: primaryHeight)
            }
            let collides = MenuCollision.collides(menuItems: items, wingZones: zones)
            await MainActor.run { [weak self] in self?.report(collides) }
        }
    }

    private func inspectNowAndAfterSettling() {
        inspect()
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            self?.inspect()
        }
    }

    private func report(_ collides: Bool) {
        guard collides != lastResult else { return }
        lastResult = collides
        onCollisionChange?(collides)
    }

    private nonisolated static func menuItemFrames(pid: pid_t) -> [CGRect] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, messagingTimeout)
        guard let menuBar = attribute(kAXMenuBarAttribute, of: app).map({ $0 as! AXUIElement }),
              let children = attribute(kAXChildrenAttribute, of: menuBar) as? [AXUIElement]
        else { return [] }
        return children.compactMap(frame(of:))
    }

    private nonisolated static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue = attribute(kAXPositionAttribute, of: element),
              let sizeValue = attribute(kAXSizeAttribute, of: element)
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size),
              size.width > 0
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private nonisolated static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard error == .success else {
            if error != .noValue && error != .attributeUnsupported {
                logger.debug("AX \(name, privacy: .public) failed: \(error.rawValue)")
            }
            return nil
        }
        return value
    }
}
