import AppKit
import Testing
@testable import NotchCore

enum RepoPaths {
    static let fonts = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Fonts")
}

@MainActor
struct BuiltInThemeTests {
    let store = ThemeStore(
        directory: FileManager.default.temporaryDirectory.appendingPathComponent("notchy-builtin-\(UUID().uuidString)"),
        defaults: UserDefaults(suiteName: "notchy-builtin-\(UUID().uuidString)")!
    )

    @Test func theFourStarterThemesAreAlwaysAvailable() {
        let ids = Set(store.themes.map(\.id))

        #expect(Theme.builtIns.map(\.name) == ["Notchy", "Cartel", "Fósforo", "Carátula"])
        #expect(Theme.builtIns.allSatisfy { ids.contains($0.id) && store.isBuiltIn($0.id) })
        #expect(Set(Theme.builtIns.map(\.id)).count == Theme.builtIns.count)
    }

    @Test func eachStarterThemeShowsADifferentPartOfTheEditor() {
        #expect(Theme.cartel.palette.panel.rgb.brightness > 0.9)
        #expect(Theme.cartel.openAnimation == .cut)
        #expect(Theme.cartel.decoration == .zigzag)
        #expect(Theme.fosforo.decoration == .scanlines)
        #expect(Theme.fosforo.openAnimation == .glitch)
        #expect(Theme.caratula.usesArtwork)
        #expect(Theme.builtIns.filter(\.usesArtwork) == [.caratula])
    }

    @Test(arguments: Theme.builtIns)
    func everyStarterThemeReachesTheContrastMinimums(_ theme: Theme) {
        let appearance = ThemeAppearance(theme: theme, background: nil)

        #expect(appearance.colorsReachMinimumOnPanel, "\(theme.name)")
    }

    @Test func builtInThemesAreReadOnly() {
        var edited = Theme.cartel
        edited.name = "Otro"

        #expect(throws: ThemeStore.StoreError.builtInTheme) { try store.save(edited) }
        #expect(throws: ThemeStore.StoreError.builtInTheme) { try store.delete(themeID: Theme.fosforo.id) }
        #expect(store.theme(id: Theme.cartel.id)?.name == "Cartel")
    }

    @Test func duplicatingAStarterThemeKeepsItsEffectsAndIsEditable() throws {
        let copy = try store.duplicate(themeID: Theme.cartel.id)

        #expect(!store.isBuiltIn(copy.id))
        #expect(copy.decoration == .zigzag)
        #expect(copy.openAnimation == .cut)
        var renamed = copy
        renamed.name = "Mi cartel"
        try store.save(renamed)
        #expect(store.theme(id: copy.id)?.name == "Mi cartel")
    }

    @Test func starterThemesUseOnlyFontsShippedWithTheApp() {
        FontRegistry.register(directory: RepoPaths.fonts)

        for family in Theme.builtIns.compactMap(\.typography.family) {
            #expect(NSFontManager.shared.availableMembers(ofFontFamily: family) != nil, "falta \(family)")
        }
    }

    @Test func builtInThemesHaveNoMediaFiles() {
        #expect(Theme.builtIns.allSatisfy { $0.background == nil })
    }
}

struct SignatureModelTests {
    @Test func starterThemesRoundTrip() throws {
        for theme in Theme.builtIns {
            let decoded = try JSONDecoder().decode(Theme.self, from: JSONEncoder().encode(theme))
            #expect(decoded == theme)
        }
    }

    @Test func themesWithoutDecorationDecodeAsPlain() throws {
        let theme = try JSONDecoder().decode(Theme.self, from: Data(#"{"id":"x","name":"Plano"}"#.utf8))

        #expect(theme.decoration == nil)
        #expect(!theme.usesArtwork)
    }

    @Test(arguments: [
        ("nixieTerminal", ThemeDecoration.scanlines), ("wallPlating", .frame), ("menacing", .stripes), ("tacticalGrid", .grid),
        ("sawTeeth", .zigzag), ("psychicRings", .rings), ("stationery", .ruled), ("waves", .waves),
    ])
    func decorationsSavedWithTheirOldNamesAreTranslated(_ old: String, _ current: ThemeDecoration) throws {
        let json = #"{"id":"x","name":"Mío","decoration":"\#(old)"}"#

        #expect(try JSONDecoder().decode(Theme.self, from: Data(json.utf8)).decoration == current)
    }

    @Test func retiredDecorationsAndEmblemsAreDroppedWithoutLosingTheTheme() throws {
        let json = #"{"id":"x","name":"Mío","decoration":"clovers","emblem":"grimoire","openAnimation":"orbit"}"#

        let theme = try JSONDecoder().decode(Theme.self, from: Data(json.utf8))

        #expect(theme.name == "Mío")
        #expect(theme.decoration == nil)
        #expect(theme.openAnimation == .spring)
    }

    @Test func openingsSavedWithTheirOldNamesAreTranslated() throws {
        let doors = #"{"id":"x","openAnimation":"gate"}"#
        let cut = #"{"id":"x","openAnimation":"slash"}"#

        #expect(try JSONDecoder().decode(Theme.self, from: Data(doors.utf8)).openAnimation == .doors)
        #expect(try JSONDecoder().decode(Theme.self, from: Data(cut.utf8)).openAnimation == .cut)
    }

    @Test func retiredFontsAreReplaced() throws {
        let stencil = ThemeTypography(design: .system, family: "Big Shoulders Stencil Display", titleWeight: .bold, labelTracking: 2)
        let tubes = ThemeTypography(design: .system, family: "Nixie One", titleWeight: .bold, labelTracking: 2)

        #expect(stencil.sanitized().family == "Big Shoulders Display")
        #expect(tubes.sanitized().family == nil)
    }

    @Test func signatureOpeningsAnimateTheShapeButRespectReduceMotion() {
        for animation in [OpenAnimation.glitch, .doors, .cut] {
            #expect(MotionPolicy(reduceMotion: false, openAnimation: animation).shapeAnimation(expanding: true) != nil)
            #expect(MotionPolicy(reduceMotion: false, openAnimation: animation).playsSignatureOpening)
            #expect(!MotionPolicy(reduceMotion: true, openAnimation: animation).playsSignatureOpening)
        }
        #expect(!MotionPolicy(reduceMotion: false, openAnimation: .spring).playsSignatureOpening)
    }
}

struct OpeningEffectTests {
    @Test func glitchEndsAtRest() {
        let last = GlitchState.keyframeSequence.last

        #expect(last == .rest)
        #expect(GlitchState.keyframeSequence.contains { $0.split > 0 })
        #expect(GlitchState.totalDuration <= 0.6)
    }

    @Test func progressOpeningsStartVisibleAndEndInvisible() {
        for kind in [OpenAnimation.doors, .cut] {
            let effect = SignatureEffect(kind)
            #expect(effect.duration > 0 && effect.duration <= 1.2)
            #expect(SignatureEffect.isFinished(progress: 1))
            #expect(!SignatureEffect.isFinished(progress: 0.5))
        }
    }

    @Test func doorsSwingOpenAndDisappear() {
        #expect(SwingDoors.angle(progress: 0) == 0)
        #expect(SwingDoors.angle(progress: 1) == SwingDoors.openAngle)
        #expect(SwingDoors.opacity(progress: 0) == 1)
        #expect(SwingDoors.opacity(progress: 1) == 0)
    }
}

@MainActor
struct LegacyMigrationTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-legacy-\(UUID().uuidString)")
    let defaults = UserDefaults(suiteName: "notchy-legacy-\(UUID().uuidString)")!

    func makeStore() -> ThemeStore {
        ThemeStore(directory: directory, defaults: defaults, trash: FakeTrash(root: directory).move)
    }

    @Test func aRetiredTemplateInUseBecomesAnEditableThemeAndRulesFollowIt() throws {
        let retired = "builtin-retirada"
        defaults.set(retired, forKey: "activeThemeID")
        let rules = AutoThemeRules(isEnabled: true, schedule: [ScheduleRule(startMinute: 480, themeID: retired)], apps: [])
        defaults.set(try JSONEncoder().encode(rules), forKey: AutoThemeController.rulesKey)

        let store = makeStore()

        let migrated = store.activeTheme
        #expect(!store.isBuiltIn(migrated.id))
        #expect(migrated.name == "Mi tema (1.0)")
        let saved = try JSONDecoder().decode(AutoThemeRules.self, from: try #require(defaults.data(forKey: AutoThemeController.rulesKey)))
        #expect(saved.schedule.first?.themeID == migrated.id)
        #expect(makeStore().themes.filter { $0.name == "Mi tema (1.0)" }.count == 1)
    }

    @Test func everyRetiredTemplateKeepsAShippedFontAndAValidShape() {
        FontRegistry.register(directory: RepoPaths.fonts)

        #expect(LegacyTemplates.count == 16)
        for theme in LegacyTemplates.all {
            #expect(theme.shape == theme.shape.sanitized())
            if let family = theme.typography.family {
                #expect(NSFontManager.shared.availableMembers(ofFontFamily: family) != nil, "falta \(family)")
            }
        }
    }

    @Test func anUneditedDefaultThemeFrom10IsReplacedByTheBuiltInOne() throws {
        var seed = Theme.notchyDefault
        seed.id = "notchy"
        let folder = directory.appendingPathComponent("notchy")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(seed).write(to: folder.appendingPathComponent(ThemeStore.themeFileName))
        defaults.set("notchy", forKey: "activeThemeID")

        let store = makeStore()

        #expect(store.theme(id: "notchy") == nil)
        #expect(store.activeThemeID == Theme.notchyDefault.id)
    }

    @Test func anEditedDefaultThemeFrom10IsKept() throws {
        var mine = Theme.notchyDefault
        mine.id = "notchy"
        mine.name = "El mío"
        let folder = directory.appendingPathComponent("notchy")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(mine).write(to: folder.appendingPathComponent(ThemeStore.themeFileName))
        defaults.set("notchy", forKey: "activeThemeID")

        let store = makeStore()

        #expect(store.activeTheme.name == "El mío")
    }
}
