import AppKit
import SwiftUI

@MainActor
public final class NotchWindowController {
    private var panels: [CGDirectDisplayID: NotchPanel] = [:]
    private var observers: [NSObjectProtocol] = []
    private var currentMode: NonNotchMode

    public init() {
        currentMode = Preferences.nonNotchMode
    }

    public func start() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild() }
            },
            center.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.preferencesChanged() }
            },
        ]
        rebuild()
    }

    public func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        panels.values.forEach { $0.close() }
        panels = [:]
    }

    private func preferencesChanged() {
        let mode = Preferences.nonNotchMode
        guard mode != currentMode else { return }
        currentMode = mode
        rebuild()
    }

    private func rebuild() {
        let layouts = Dictionary(
            NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NotchLayout)? in
                guard let id = screen.displayID else { return nil }
                return (id, NotchGeometry.layout(for: ScreenMetrics(screen: screen), nonNotchMode: currentMode))
            },
            uniquingKeysWith: { first, _ in first }
        )

        for (id, panel) in panels where layouts[id]?.frame == nil {
            panel.close()
            panels[id] = nil
        }

        for (id, layout) in layouts {
            guard let frame = layout.frame else { continue }
            let panel = panels[id] ?? makePanel(frame: frame)
            panel.contentView = NSHostingView(rootView: IslandView(isNotch: layout.isNotch))
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            panels[id] = panel
        }
    }

    private func makePanel(frame: CGRect) -> NotchPanel {
        NotchPanel(frame: frame)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
