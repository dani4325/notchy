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
    private let menuInspector = MenuBarInspector()

    public init(nowPlaying: NowPlayingStore, companion: CompanionStore, wings: WingsVisibility) {
        self.wings = wings
        self.nowPlaying = nowPlaying
        self.companion = companion
        currentMode = Preferences.nonNotchMode
    }

    public func start() {
        menuInspector.wingZones = { [weak self] in
            self?.islands.values.flatMap(\.wingZones) ?? []
        }
        menuInspector.onCollisionChange = { [weak self] collide in
            self?.wings.setMenusCollide(collide)
        }
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
        menuInspector.start()
    }

    public func stop() {
        menuInspector.stop()
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
        let screens = NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NotchLayout, ScreenMetrics)? in
            guard let id = screen.displayID else { return nil }
            let metrics = ScreenMetrics(screen: screen)
            return (id, NotchGeometry.layout(for: metrics, nonNotchMode: currentMode), metrics)
        }
        let visibleIDs = Set(screens.compactMap { id, layout, _ in layout.frame == nil ? nil : id })

        for (id, island) in islands where !visibleIDs.contains(id) {
            island.close()
            islands[id] = nil
        }

        for (id, layout, metrics) in screens {
            guard let frame = layout.frame else { continue }
            let kind: IslandKind = layout.isNotch ? .notch : .pill
            let strip = NotchGeometry.stripHeight(collapsed: frame, screen: metrics)
            if let island = islands[id] {
                island.update(collapsedFrame: frame, kind: kind, screenFrame: metrics.frame, stripHeight: strip)
            } else {
                islands[id] = IslandPanelController(
                    collapsedFrame: frame, kind: kind, screenFrame: metrics.frame, stripHeight: strip,
                    nowPlaying: nowPlaying, companion: companion, wings: wings
                )
            }
        }
        menuInspector.inspect()
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
