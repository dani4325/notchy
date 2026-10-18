import AppKit
import SwiftUI

@MainActor
public final class NotchWindowController {
    private var islands: [CGDirectDisplayID: IslandPanelController] = [:]
    private var observers: [NSObjectProtocol] = []
    private var currentMode: NonNotchMode
    private let nowPlaying: NowPlayingStore
    private let companion: CompanionStore
    private let wings: WingsVisibility

    public init(nowPlaying: NowPlayingStore, companion: CompanionStore, wings: WingsVisibility) {
        self.wings = wings
        self.nowPlaying = nowPlaying
        self.companion = companion
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
        islands.values.forEach { $0.close() }
        islands = [:]
    }

    private func preferencesChanged() {
        let mode = Preferences.nonNotchMode
        guard mode != currentMode else { return }
        currentMode = mode
        rebuild()
    }

    private func rebuild() {
        let screens = NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NotchLayout, CGRect)? in
            guard let id = screen.displayID else { return nil }
            let layout = NotchGeometry.layout(for: ScreenMetrics(screen: screen), nonNotchMode: currentMode)
            return (id, layout, screen.frame)
        }
        let visibleIDs = Set(screens.compactMap { id, layout, _ in layout.frame == nil ? nil : id })

        for (id, island) in islands where !visibleIDs.contains(id) {
            island.close()
            islands[id] = nil
        }

        for (id, layout, screenFrame) in screens {
            guard let frame = layout.frame else { continue }
            let kind: IslandKind = layout.isNotch ? .notch : .pill
            if let island = islands[id] {
                island.update(collapsedFrame: frame, kind: kind, screenFrame: screenFrame)
            } else {
                islands[id] = IslandPanelController(
                    collapsedFrame: frame, kind: kind, screenFrame: screenFrame,
                    nowPlaying: nowPlaying, companion: companion, wings: wings
                )
            }
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
