import AppKit
import Observation
import os
import UniformTypeIdentifiers

@MainActor
@Observable
public final class AutoThemeController {
    public private(set) var rules: AutoThemeRules

    @ObservationIgnored private let store: ThemeStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var nextChangeTimer: Task<Void, Never>?

    private static let rulesKey = "autoThemeRules"
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "autotheme")
    private static let defaultDayStart = 8 * 60
    private static let defaultNightStart = 21 * 60

    public init(store: ThemeStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        rules = defaults.data(forKey: Self.rulesKey)
            .flatMap { try? JSONDecoder().decode(AutoThemeRules.self, from: $0) } ?? .empty
    }

    public func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        let local = NotificationCenter.default
        let events: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didActivateApplicationNotification),
            (workspace, NSWorkspace.didWakeNotification),
            (local, .NSSystemClockDidChange),
            (local, .NSSystemTimeZoneDidChange),
        ]
        observers = events.map { center, name in
            (center, center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            })
        }
        evaluate()
    }

    public func stop() {
        observers.forEach { center, token in center.removeObserver(token) }
        observers = []
        nextChangeTimer?.cancel()
        store.setOverride(themeID: nil)
    }

    public func setEnabled(_ enabled: Bool) {
        change { $0.isEnabled = enabled }
    }

    public func addScheduleRule() {
        let used = Set(rules.schedule.map(\.startMinute))
        let start = [Self.defaultDayStart, Self.defaultNightStart].first { !used.contains($0) } ?? 12 * 60
        change { $0.schedule.append(ScheduleRule(startMinute: start, themeID: store.activeThemeID)) }
    }

    public func updateSchedule(_ id: UUID, startMinute: Int? = nil, themeID: String? = nil) {
        change { rules in
            guard let index = rules.schedule.firstIndex(where: { $0.id == id }) else { return }
            if let startMinute { rules.schedule[index].startMinute = startMinute.clamped(to: 0...(AutoThemeResolver.minutesPerDay - 1)) }
            if let themeID { rules.schedule[index].themeID = themeID }
        }
    }

    public func removeSchedule(_ id: UUID) {
        change { $0.schedule.removeAll { $0.id == id } }
    }

    public func addAppFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = String(localized: "Elige la app que cambiará el tema cuando esté en primer plano")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier
        else { return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        change { rules in
            guard !rules.apps.contains(where: { $0.bundleID == bundleID }) else { return }
            rules.apps.append(AppRule(bundleID: bundleID, appName: name, themeID: store.activeThemeID))
        }
    }

    public func updateApp(_ id: UUID, themeID: String) {
        change { rules in
            guard let index = rules.apps.firstIndex(where: { $0.id == id }) else { return }
            rules.apps[index].themeID = themeID
        }
    }

    public func removeApp(_ id: UUID) {
        change { $0.apps.removeAll { $0.id == id } }
    }

    private func change(_ mutation: (inout AutoThemeRules) -> Void) {
        var updated = rules
        mutation(&updated)
        guard updated != rules else { return }
        rules = updated
        do {
            defaults.set(try JSONEncoder().encode(updated), forKey: Self.rulesKey)
        } catch {
            Self.logger.error("rules save failed: \(error.localizedDescription, privacy: .public)")
        }
        evaluate()
    }

    private func evaluate() {
        let now = Date()
        let calendar = Calendar.current
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        store.setOverride(themeID: AutoThemeResolver.themeID(
            rules: rules,
            minuteOfDay: AutoThemeResolver.minuteOfDay(now, calendar: calendar),
            frontmostBundleID: frontmost
        ))
        scheduleNextChange(after: now, calendar: calendar)
    }

    private func scheduleNextChange(after now: Date, calendar: Calendar) {
        nextChangeTimer?.cancel()
        nextChangeTimer = nil
        guard let next = AutoThemeResolver.nextChange(rules: rules, after: now, calendar: calendar) else { return }
        nextChangeTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(next.timeIntervalSince(now)))
            guard !Task.isCancelled else { return }
            self?.evaluate()
        }
    }
}
