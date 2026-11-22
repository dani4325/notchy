import Foundation
import Testing
@testable import NotchCore

struct AutoThemeResolverTests {
    let day = ScheduleRule(startMinute: 8 * 60, themeID: "tema-de-dia")
    let night = ScheduleRule(startMinute: 21 * 60, themeID: "tokyo")
    let xcode = AppRule(bundleID: "com.apple.dt.Xcode", appName: "Xcode", themeID: "steins")

    var rules: AutoThemeRules { AutoThemeRules(isEnabled: true, schedule: [night, day], apps: [xcode]) }

    @Test func scheduleAppliesTheLatestStartedSlot() {
        #expect(AutoThemeResolver.themeID(rules: rules, minuteOfDay: 9 * 60, frontmostBundleID: nil) == "tema-de-dia")
        #expect(AutoThemeResolver.themeID(rules: rules, minuteOfDay: 22 * 60, frontmostBundleID: nil) == "tokyo")
    }

    @Test func slotsWrapAroundMidnight() {
        #expect(AutoThemeResolver.themeID(rules: rules, minuteOfDay: 2 * 60, frontmostBundleID: nil) == "tokyo")
    }

    @Test func appRuleWinsOverSchedule() {
        #expect(AutoThemeResolver.themeID(rules: rules, minuteOfDay: 9 * 60, frontmostBundleID: "com.apple.dt.Xcode") == "steins")
        #expect(AutoThemeResolver.themeID(rules: rules, minuteOfDay: 9 * 60, frontmostBundleID: "com.apple.Safari") == "tema-de-dia")
    }

    @Test func disabledOrEmptyRulesNeverOverride() {
        var disabled = rules
        disabled.isEnabled = false

        #expect(AutoThemeResolver.themeID(rules: disabled, minuteOfDay: 9 * 60, frontmostBundleID: "com.apple.dt.Xcode") == nil)
        #expect(AutoThemeResolver.themeID(rules: AutoThemeRules(isEnabled: true, schedule: [], apps: []), minuteOfDay: 0, frontmostBundleID: nil) == nil)
    }

    @Test func nextChangeIsTheNextSlotStartTodayOrTomorrow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 9, minute: 30)))
        let lateNight = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 23, minute: 0)))

        let first = try #require(AutoThemeResolver.nextChange(rules: rules, after: morning, calendar: calendar))
        let second = try #require(AutoThemeResolver.nextChange(rules: rules, after: lateNight, calendar: calendar))

        #expect(calendar.dateComponents([.day, .hour, .minute], from: first) == DateComponents(day: 18, hour: 21, minute: 0))
        #expect(calendar.dateComponents([.day, .hour, .minute], from: second) == DateComponents(day: 19, hour: 8, minute: 0))
    }

    @Test func noScheduleMeansNoTimer() {
        let appsOnly = AutoThemeRules(isEnabled: true, schedule: [], apps: [xcode])

        #expect(AutoThemeResolver.nextChange(rules: appsOnly, after: .now, calendar: .current) == nil)
    }

    @Test func rulesSurviveEncoding() throws {
        let decoded = try JSONDecoder().decode(AutoThemeRules.self, from: JSONEncoder().encode(rules))

        #expect(decoded == rules)
    }
}

@MainActor
struct ThemeOverrideTests {
    @Test func overrideChangesTheShownThemeWithoutTouchingTheChosenOne() {
        let store = ThemeStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent("notchy-override-\(UUID().uuidString)"),
            defaults: UserDefaults(suiteName: "notchy-override-\(UUID().uuidString)")!
        )

        store.setOverride(themeID: Theme.cartel.id)
        #expect(store.activeTheme.id == Theme.cartel.id)
        #expect(store.activeThemeID == Theme.notchyDefault.id)

        store.setOverride(themeID: "no-existe")
        #expect(store.activeTheme.id == Theme.notchyDefault.id)

        store.setOverride(themeID: nil)
        #expect(store.activeTheme.id == Theme.notchyDefault.id)
    }
}

@MainActor
struct AutoThemeRulesProblemTests {
    @Test func damagedSavedRulesAreResetWithAWarning() {
        let defaults = UserDefaults(suiteName: "autotheme-\(UUID().uuidString)")!
        defaults.set(Data("dañado".utf8), forKey: "autoThemeRules")
        let store = ThemeStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent("autotheme-\(UUID().uuidString)"),
            defaults: defaults
        )

        let controller = AutoThemeController(store: store, defaults: defaults)

        #expect(controller.rules == .empty)
        #expect(controller.problem != nil)
    }
}
