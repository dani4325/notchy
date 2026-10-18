import Foundation

public struct ScheduleRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var startMinute: Int
    public var themeID: String

    public init(id: UUID = UUID(), startMinute: Int, themeID: String) {
        self.id = id
        self.startMinute = startMinute
        self.themeID = themeID
    }
}

public struct AppRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var bundleID: String
    public var appName: String
    public var themeID: String

    public init(id: UUID = UUID(), bundleID: String, appName: String, themeID: String) {
        self.id = id
        self.bundleID = bundleID
        self.appName = appName
        self.themeID = themeID
    }
}

public struct AutoThemeRules: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var schedule: [ScheduleRule]
    public var apps: [AppRule]

    public static let empty = AutoThemeRules(isEnabled: false, schedule: [], apps: [])
}

enum AutoThemeResolver {
    static let minutesPerDay = 24 * 60

    static func themeID(rules: AutoThemeRules, minuteOfDay: Int, frontmostBundleID: String?) -> String? {
        guard rules.isEnabled else { return nil }
        if let bundleID = frontmostBundleID, let app = rules.apps.first(where: { $0.bundleID == bundleID }) {
            return app.themeID
        }
        let ordered = rules.schedule.sorted { $0.startMinute < $1.startMinute }
        guard let last = ordered.last else { return nil }
        return (ordered.last { $0.startMinute <= minuteOfDay } ?? last).themeID
    }

    static func nextChange(rules: AutoThemeRules, after date: Date, calendar: Calendar) -> Date? {
        guard rules.isEnabled else { return nil }
        let starts = Set(rules.schedule.map { $0.startMinute.clamped(to: 0...(minutesPerDay - 1)) })
        return starts.compactMap { minute in
            calendar.nextDate(
                after: date,
                matching: DateComponents(hour: minute / 60, minute: minute % 60, second: 0),
                matchingPolicy: .nextTime
            )
        }
        .min()
    }

    static func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
