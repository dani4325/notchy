import AppKit
import Observation

public enum MusicSourceMode: String, CaseIterable, Sendable {
    case automatic
    case appleScript
}

public enum ActiveMusicSource: Equatable, Sendable {
    case checking
    case mediaRemote
    case appleScript(fallback: Bool)
}

@MainActor
@Observable
public final class NowPlayingStore {
    public private(set) var info: NowPlayingInfo?
    public private(set) var artwork: NSImage?
    public private(set) var appName: String?
    public private(set) var activeSource: ActiveMusicSource = .checking

    public var isPlaying: Bool { info?.isPlaying ?? false }

    @ObservationIgnored private var source: NowPlayingSource?
    @ObservationIgnored private var mode: MusicSourceMode = Preferences.musicSourceMode
    @ObservationIgnored private var defaultsObserver: NSObjectProtocol?
    @ObservationIgnored private var startTask: Task<Void, Never>?

    public init() {}

    public func start() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.preferencesChanged() }
        }
        connect()
    }

    public func stop() {
        defaultsObserver.map(NotificationCenter.default.removeObserver)
        defaultsObserver = nil
        disconnect()
    }

    func send(_ command: MediaCommand) {
        source?.send(command)
    }

    public func togglePlayPause() { send(.togglePlayPause) }
    public func nextTrack() { send(.nextTrack) }
    public func previousTrack() { send(.previousTrack) }

    private func preferencesChanged() {
        let newMode = Preferences.musicSourceMode
        guard newMode != mode else { return }
        mode = newMode
        disconnect()
        connect()
    }

    private func connect() {
        activeSource = .checking
        startTask = Task {
            guard mode == .automatic, let paths = AdapterPaths.inBundle(),
                  await AdapterSource.selfTest(paths: paths)
            else {
                use(AppleScriptSource(), as: .appleScript(fallback: mode == .automatic))
                return
            }
            guard !Task.isCancelled else { return }
            use(AdapterSource(paths: paths), as: .mediaRemote)
        }
    }

    private func disconnect() {
        startTask?.cancel()
        source?.stop()
        source = nil
        apply(nil)
    }

    private func use(_ newSource: NowPlayingSource, as kind: ActiveMusicSource) {
        guard !Task.isCancelled else { return }
        newSource.onUpdate = { [weak self] info in self?.apply(info) }
        newSource.onFailure = { [weak self] in self?.adapterFailed() }
        source = newSource
        activeSource = kind
        newSource.start()
    }

    private func adapterFailed() {
        guard activeSource == .mediaRemote else { return }
        source?.stop()
        apply(nil)
        use(AppleScriptSource(), as: .appleScript(fallback: true))
    }

    private func apply(_ newInfo: NowPlayingInfo?) {
        guard newInfo != info else { return }
        if newInfo?.artworkData != info?.artworkData {
            artwork = newInfo?.artworkData.flatMap(NSImage.init(data:))
        }
        if newInfo?.appBundleID != info?.appBundleID {
            appName = newInfo.flatMap { Self.displayName(forBundleID: $0.appBundleID) }
        }
        info = newInfo
    }

    private static func displayName(forBundleID bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
