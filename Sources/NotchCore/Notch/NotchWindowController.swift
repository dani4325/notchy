import AppKit
import Observation
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
    private let visualizer = AudioVisualizer()
    private let shelf: ShelfStore
    private let menuInspector = MenuBarInspector()
    private var wakeObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var collidingDisplays: Set<CGDirectDisplayID> = []
    private var artworkTask: Task<Void, Never>?
    private var lastArtworkRequest: (revision: Int, isNeeded: Bool)?
    private var isStarted = false
    private var nudgeCount = 0
    public var onVolumeStep: ((MediaKeyKind) -> Void)?

    public init(
        nowPlaying: NowPlayingStore, companion: CompanionStore, wings: WingsVisibility, themes: ThemeStore, shelf: ShelfStore
    ) {
        self.shelf = shelf
        self.themes = themes
        self.wings = wings
        self.nowPlaying = nowPlaying
        self.companion = companion
        currentMode = Preferences.nonNotchMode
    }

    public func start() {
        isStarted = true
        let workspace = NSWorkspace.shared.notificationCenter
        wakeObserver = workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
        spaceObserver = workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.islands.values.forEach { $0.bringToFront() }
                self?.menuInspector.inspect()
            }
        }
        menuInspector.wingZonesByDisplay = { [weak self] in
            self?.islands.mapValues(\.wingZones) ?? [:]
        }
        menuInspector.onCollisionChange = { [weak self] colliding in
            self?.applyMenuCollisions(colliding)
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
        observeArtworkBackdrop()
        rebuild()
        menuInspector.start()
    }

    public func stop() {
        isStarted = false
        artworkTask?.cancel()
        artworkTask = nil
        lastArtworkRequest = nil
        wakeObserver.map(NSWorkspace.shared.notificationCenter.removeObserver)
        wakeObserver = nil
        spaceObserver.map(NSWorkspace.shared.notificationCenter.removeObserver)
        spaceObserver = nil
        menuInspector.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        collidingDisplays = []
        islands.values.forEach { $0.close() }
        islands = [:]
    }

    public func show(_ event: PowerEvent) {
        guard Preferences.chargingAnimation else { return }
        islands.values.forEach { $0.show(.power(event)) }
    }

    public func greet() {
        islands.values.forEach { $0.show(.greeting) }
    }

    public func show(_ reading: VolumeReading, direction: VolumeNudge.Direction?, limit: VolumeLimit?) {
        guard Preferences.volumeHUD else { return }
        let nudge = direction.map { direction -> VolumeNudge in
            nudgeCount += 1
            return VolumeNudge(direction: direction, limit: limit, count: nudgeCount)
        }
        islands.values.forEach { $0.show(.volume(reading, nudge)) }
    }

    private func applyMenuCollisions(_ colliding: Set<CGDirectDisplayID>) {
        collidingDisplays = colliding
        for (id, island) in islands {
            island.setMenusCollide(colliding.contains(id))
        }
    }

    private func observeArtworkBackdrop() {
        let request = (revision: nowPlaying.artworkRevision, isNeeded: themes.activeTheme.usesArtwork)
        if lastArtworkRequest.map({ $0.revision != request.revision || $0.isNeeded != request.isNeeded }) ?? true {
            lastArtworkRequest = request
            let data = request.isNeeded ? nowPlaying.info?.artworkData : nil
            artworkTask?.cancel()
            artworkTask = Task { [themes] in
                await themes.artworkBackdrop.prepare(artwork: data)
            }
        }
        withObservationTracking {
            _ = nowPlaying.artworkRevision
            _ = themes.activeTheme.usesArtwork
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isStarted else { return }
                self.observeArtworkBackdrop()
            }
        }
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
                let island = IslandPanelController(
                    collapsedFrame: placement.collapsedFrame, kind: placement.kind,
                    screenFrame: placement.screenFrame, stripHeight: placement.stripHeight,
                    nowPlaying: nowPlaying, companion: companion, wings: wings, themes: themes,
                    visualizer: visualizer, shelf: shelf,
                    stepVolume: { [weak self] kind in self?.onVolumeStep?(kind) }
                )
                island.setMenusCollide(collidingDisplays.contains(placement.displayID))
                islands[placement.displayID] = island
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
