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

    @Test func everyAnimeTemplateIsAlwaysAvailable() {
        let ids = Set(store.themes.map(\.id))

        #expect(Theme.builtIns.count == 16)
        #expect(Theme.builtIns.allSatisfy { ids.contains($0.id) && store.isBuiltIn($0.id) })
        #expect(!store.isBuiltIn(Theme.notchyDefault.id))
        #expect(Set(Theme.builtIns.map(\.id)).count == Theme.builtIns.count)
        for name in ["Steins;Gate", "Attack on Titan", "JoJo's Bizarre Adventure", "Bleach", "Orb: On the Movements of the Earth",
                     "Tokyo Ghoul", "86 Eighty-Six", "Black Clover", "Jujutsu Kaisen", "Chainsaw Man", "Fullmetal Alchemist",
                     "Frieren: Beyond Journey's End", "One Piece", "Naruto", "Violet Evergarden", "Mob Psycho 100"] {
            #expect(Theme.builtIns.contains { $0.name == name }, "falta \(name)")
        }
    }

    @Test func everyTemplateHasItsOwnSignature() {
        #expect(Set(Theme.builtIns.compactMap(\.decoration)).count == Theme.builtIns.count)
        #expect(Set(ThemeDecoration.allCases).count == Theme.builtIns.count)
    }

    @Test func builtInThemesAreReadOnly() {
        var edited = Theme.steinsGate
        edited.name = "Otro"

        #expect(throws: ThemeStore.StoreError.builtInTheme) { try store.save(edited) }
        #expect(throws: ThemeStore.StoreError.builtInTheme) { try store.delete(themeID: Theme.attackOnTitan.id) }
        #expect(store.theme(id: Theme.steinsGate.id)?.name == "Steins;Gate")
    }

    @Test func duplicatingABuiltInThemeKeepsItsSignatureAndIsEditable() throws {
        let copy = try store.duplicate(themeID: Theme.attackOnTitan.id)

        #expect(!store.isBuiltIn(copy.id))
        #expect(copy.decoration == .wallPlating)
        #expect(copy.openAnimation == .gate)
        var renamed = copy
        renamed.name = "Mi muralla"
        try store.save(renamed)
        #expect(store.theme(id: copy.id)?.name == "Mi muralla")
    }

    @Test func builtInThemesUseOnlyFontsShippedWithTheApp() throws {
        FontRegistry.register(directory: RepoPaths.fonts)

        for theme in Theme.builtIns {
            let family = try #require(theme.typography.family)
            #expect(NSFontManager.shared.availableMembers(ofFontFamily: family) != nil, "falta \(family)")
        }
        #expect(NSFontManager.shared.availableMembers(ofFontFamily: NixieStyle.fontFamily) != nil)
    }

    @Test func builtInThemesHaveNoMediaFiles() {
        #expect(Theme.builtIns.allSatisfy { $0.background == nil })
    }
}

struct SignatureModelTests {
    @Test func decorationAndNewAnimationsRoundTrip() throws {
        for theme in Theme.builtIns {
            let decoded = try JSONDecoder().decode(Theme.self, from: JSONEncoder().encode(theme))
            #expect(decoded == theme)
        }
    }

    @Test func themesWithoutDecorationDecodeAsPlain() throws {
        let theme = try JSONDecoder().decode(Theme.self, from: Data(#"{"id":"x","name":"Plano"}"#.utf8))

        #expect(theme.decoration == nil)
    }

    @Test func signatureOpeningsAnimateTheShapeButRespectReduceMotion() {
        for animation in [OpenAnimation.glitch, .gate, .menacing, .slash, .orbit] {
            #expect(MotionPolicy(reduceMotion: false, openAnimation: animation).shapeAnimation(expanding: true) != nil)
            #expect(MotionPolicy(reduceMotion: false, openAnimation: animation).playsSignatureOpening)
            #expect(!MotionPolicy(reduceMotion: true, openAnimation: animation).playsSignatureOpening)
        }
        #expect(!MotionPolicy(reduceMotion: false, openAnimation: .spring).playsSignatureOpening)
    }
}

struct NixieReadoutTests {
    @Test func splitsTimeIntoTubesAndSeparators() {
        #expect(NixieReadout.symbols("12:05") == [.digit("1"), .digit("2"), .separator, .digit("0"), .digit("5")])
        #expect(NixieReadout.symbols("-3:41") == [.sign, .digit("3"), .separator, .digit("4"), .digit("1")])
    }

    @Test func ignoresUnexpectedCharacters() {
        #expect(NixieReadout.symbols("1a") == [.digit("1")])
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
        for kind in [OpenAnimation.gate, .menacing, .slash, .orbit] {
            let effect = SignatureEffect(kind)
            #expect(effect.duration > 0 && effect.duration <= 1.2)
            #expect(SignatureEffect.isFinished(progress: 1))
            #expect(!SignatureEffect.isFinished(progress: 0.5))
        }
    }

    @Test func gateDoorsSwingOpenAndDisappear() {
        #expect(GateDoors.angle(progress: 0) == 0)
        #expect(GateDoors.angle(progress: 1) == GateDoors.openAngle)
        #expect(GateDoors.opacity(progress: 0) == 1)
        #expect(GateDoors.opacity(progress: 1) == 0)
        #expect(GateDoors.angle(progress: 0.5) > 0 && GateDoors.angle(progress: 0.5) < GateDoors.openAngle)
    }
}

struct EmblemTests {
    @Test func everyTemplateHasItsOwnEmblem() {
        let emblems = Theme.builtIns.compactMap(\.emblem)

        #expect(emblems.count == Theme.builtIns.count)
        #expect(Set(emblems).count == emblems.count)
        #expect(Set(ThemeEmblem.allCases).count == Theme.builtIns.count)
    }

    @Test func emblemSurvivesEncodingAndPlainThemesHaveNone() throws {
        let decoded = try JSONDecoder().decode(Theme.self, from: JSONEncoder().encode(Theme.onePiece))

        #expect(decoded.emblem == .strawHat)
        #expect(Theme.notchyDefault.emblem == nil)
    }

    @Test func nixieReadoutSupportsDecimalPoint() {
        #expect(NixieReadout.symbols("1.04") == [.digit("1"), .dot, .digit("0"), .digit("4")])
    }
}
