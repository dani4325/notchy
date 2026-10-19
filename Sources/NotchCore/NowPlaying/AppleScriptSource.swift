import AppKit
import os

@MainActor
final class AppleScriptSource: NowPlayingSource {
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "applescript")
    private static let fieldSeparator = "\u{1F}"

    var onUpdate: ((NowPlayingInfo?) -> Void)?
    var onFailure: (() -> Void)?

    private let runner = AppleScriptRunner()
    private var observers: [NSObjectProtocol] = []
    private var current: (app: PlayerApp, info: NowPlayingInfo)?
    private var artworkTask: Task<Void, Never>?
    private var initialTask: Task<Void, Never>?
    private var isStopped = true

    func start() {
        let center = DistributedNotificationCenter.default()
        observers = PlayerApp.allCases.map { app in
            center.addObserver(forName: app.notificationName, object: nil, queue: .main) { [weak self] note in
                let userInfo = note.userInfo ?? [:]
                let info = app.info(from: userInfo, now: Date())
                MainActor.assumeIsolated { self?.received(info, from: app) }
            }
        }
        isStopped = false
        initialTask = Task { [weak self] in await self?.loadInitialState() }
    }

    func stop() {
        observers.forEach(DistributedNotificationCenter.default().removeObserver)
        observers = []
        artworkTask?.cancel()
        initialTask?.cancel()
        isStopped = true
        current = nil
    }

    func send(_ command: MediaCommand) {
        guard let app = current?.app, isRunning(app) else { return }
        let script = "tell application \"\(app.scriptName)\" to \(command.appleScriptVerb)"
        Task { _ = await runner.string(script) }
    }

    private func received(_ info: NowPlayingInfo?, from app: PlayerApp) {
        guard !isStopped else { return }
        guard let info else {
            if current?.app == app {
                current = nil
                onUpdate?(nil)
            }
            return
        }
        let previous = current?.info
        let isSameTrack = previous?.trackKey == info.trackKey
        let merged = info.withArtwork(isSameTrack ? previous?.artworkData : nil)
        current = (app, merged)
        onUpdate?(merged)

        if app == .music {
            Task { await refreshPosition(for: app) }
        }
        if !isSameTrack {
            loadArtwork(for: app, trackKey: info.trackKey)
        }
    }

    private func loadInitialState() async {
        for app in PlayerApp.allCases where isRunning(app) {
            let script = """
            tell application "\(app.scriptName)"
                if player state is stopped then return ""
                set t to current track
                return (player state as text) & "\(Self.fieldSeparator)" & (name of t) & "\(Self.fieldSeparator)" & (artist of t) & "\(Self.fieldSeparator)" & (album of t) & "\(Self.fieldSeparator)" & (duration of t) & "\(Self.fieldSeparator)" & player position
            end tell
            """
            guard let output = await runner.string(script), !output.isEmpty else { continue }
            let parts = output.components(separatedBy: Self.fieldSeparator)
            guard parts.count == 6 else { continue }

            let durationRaw = Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0
            let durationMillis = app == .spotify ? durationRaw : durationRaw * 1000
            let userInfo: [AnyHashable: Any] = [
                "Player State": parts[0].capitalized,
                "Name": parts[1], "Artist": parts[2], "Album": parts[3],
                (app == .spotify ? "Duration" : "Total Time"): durationMillis,
                "Playback Position": Double(parts[5].replacingOccurrences(of: ",", with: ".")) ?? 0,
            ]
            received(app.info(from: userInfo, now: Date()), from: app)
            if current?.info.isPlaying == true { return }
        }
    }

    private func refreshPosition(for app: PlayerApp) async {
        guard isRunning(app) else { return }
        let script = "tell application \"\(app.scriptName)\" to return player position"
        guard let raw = await runner.string(script),
              let position = Double(raw.replacingOccurrences(of: ",", with: ".")),
              let current, current.app == app
        else { return }
        let updated = current.info.withPosition(position, at: Date())
        self.current = (app, updated)
        onUpdate?(updated)
    }

    private func loadArtwork(for app: PlayerApp, trackKey: String) {
        artworkTask?.cancel()
        guard isRunning(app) else { return }
        artworkTask = Task { [runner] in
            let data: Data?
            switch app {
            case .spotify:
                let urlString = await runner.string("tell application \"Spotify\" to return artwork url of current track")
                data = await Self.download(urlString)
            case .music:
                data = await runner.data("tell application \"Music\" to return raw data of artwork 1 of current track")
            }
            guard !Task.isCancelled, let data, let current, current.info.trackKey == trackKey else { return }
            let updated = current.info.withArtwork(data)
            self.current = (current.app, updated)
            onUpdate?(updated)
        }
    }

    private static func download(_ urlString: String?) async -> Data? {
        guard let urlString, let url = URL(string: urlString), url.scheme == "https" else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            logger.error("artwork download failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func isRunning(_ app: PlayerApp) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty
    }
}

final class AppleScriptRunner: Sendable {
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "applescript")
    private let queue = DispatchQueue(label: "com.danirubio.notchy.applescript")

    func string(_ source: String) async -> String? {
        await execute(source) { $0.stringValue }
    }

    func data(_ source: String) async -> Data? {
        await execute(source) { $0.data.isEmpty ? nil : $0.data }
    }

    private func execute<T: Sendable>(_ source: String, extract: @escaping @Sendable (NSAppleEventDescriptor) -> T?) async -> T? {
        await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
                if let error {
                    Self.logger.error("script failed: \(error, privacy: .public)")
                }
                continuation.resume(returning: result.flatMap(extract))
            }
        }
    }
}
