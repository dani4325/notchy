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
    private let themes: ThemeStore
    private let menuInspector = MenuBarInspector()
    private var wakeObserver: NSObjectProtocol?

    public init(nowPlaying: NowPlayingStore, companion: CompanionStore, wings: WingsVisibility, themes: ThemeStore) {
        self.themes = themes
        self.wings = wings
        self.nowPlaying = nowPlaying
        self.companion = companion
        currentMode = Preferences.nonNotchMode
    }

    public func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        wakeObserver = workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
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
        wakeObserver.map(NSWorkspace.shared.notificationCenter.removeObserver)
        wakeObserver = nil
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
        let screens = NSScreen.screens.compactMap { screen in
            screen.displayID.map { ($0, ScreenMetrics(screen: screen)) }
        }
        let placements = ScreenPlan.islands(for: screens, nonNotchMode: currentMode)
        let visibleIDs = Set(placements.map(\.displayID))

        for (id, island) in islands where !visibleIDs.contains(id) {
            island.close()
            islands[id] = nil
        }

        for placement in placements {
            if let island = islands[placement.displayID] {
                island.update(
                    collapsedFrame: placement.collapsedFrame, kind: placement.kind,
                    screenFrame: placement.screenFrame, stripHeight: placement.stripHeight
                )
            } else {
                islands[placement.displayID] = IslandPanelController(
                    collapsedFrame: placement.collapsedFrame, kind: placement.kind,
                    screenFrame: placement.screenFrame, stripHeight: placement.stripHeight,
                    nowPlaying: nowPlaying, companion: companion, wings: wings, themes: themes
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
