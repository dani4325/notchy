import AppKit
import Testing
@testable import NotchCore

@MainActor
struct ThemeEditorModelTests {
    let store = ThemeStore(
        directory: FileManager.default.temporaryDirectory.appendingPathComponent("notchy-editor-\(UUID().uuidString)"),
        defaults: UserDefaults(suiteName: "notchy-editor-\(UUID().uuidString)")!
    )

    @Test func startsEditingTheActiveTheme() {
        let editor = ThemeEditorModel(store: store)

        #expect(editor.draft?.id == store.activeTheme.id)
    }

    @Test func editsChangeTheDraftAndPersistOnFlush() {
        let editor = ThemeEditorModel(store: store)

        editor.update { $0.name = "Nocturno" }
        #expect(editor.draft?.name == "Nocturno")

        editor.flush()
        #expect(store.activeTheme.name == "Nocturno")
    }

    @Test func editingAColorSwitchesPaletteToManual() throws {
        let editor = ThemeEditorModel(store: store)
        editor.update { $0.palette.source = .automatic }

        editor.setColor(\.accent, to: try #require(HexColor("#00FF88")))

        #expect(editor.draft?.palette.accent.hex == "#00FF88")
        #expect(editor.draft?.palette.source == .manual)
    }

    @Test func extractedPaletteOnlyReplacesAutomaticPalettes() throws {
        let editor = ThemeEditorModel(store: store)
        let extracted = PaletteBuilder.palette(from: [.init(color: RGB(red: 0.1, green: 0.8, blue: 0.3), weight: 1)])

        editor.update { $0.palette.source = .manual }
        editor.applyExtracted(extracted, force: false)
        #expect(editor.draft?.palette.accent != extracted.accent)

        editor.update { $0.palette.source = .automatic }
        editor.applyExtracted(extracted, force: false)
        #expect(editor.draft?.palette.accent == extracted.accent)
    }

    @Test func forcedExtractionAlwaysAppliesAndMarksAutomatic() throws {
        let editor = ThemeEditorModel(store: store)
        editor.update { $0.palette.source = .manual }
        let extracted = PaletteBuilder.palette(from: [.init(color: RGB(red: 0.9, green: 0.2, blue: 0.6), weight: 1)])

        editor.applyExtracted(extracted, force: true)

        #expect(editor.draft?.palette == extracted)
    }

    @Test func selectingAnotherThemeFlushesPendingEdits() throws {
        let editor = ThemeEditorModel(store: store)
        let copy = try store.duplicate(themeID: store.activeTheme.id)
        editor.update { $0.name = "Guardado al cambiar" }

        editor.select(themeID: copy.id)

        #expect(store.theme(id: Theme.notchyDefault.id)?.name == "Guardado al cambiar")
        #expect(editor.draft?.id == copy.id)
    }
}

@MainActor
struct ThemeEditorBackgroundBindingTests {
    let store = ThemeStore(
        directory: FileManager.default.temporaryDirectory.appendingPathComponent("notchy-editor-\(UUID().uuidString)"),
        defaults: UserDefaults(suiteName: "notchy-editor-\(UUID().uuidString)")!
    )

    @Test func backgroundBindingIsSafeWithoutBackground() {
        let editor = ThemeEditorModel(store: store)
        let zoom = editor.backgroundBinding(\.media.crop.zoom, fallback: 1)

        #expect(zoom.wrappedValue == 1)
        zoom.wrappedValue = 3
        #expect(editor.draft?.background == nil)
    }

    @Test func createThemeStartsFromCleanDefaults() throws {
        let editor = ThemeEditorModel(store: store)
        editor.update { $0.background = ThemeBackground(media: ThemeMedia(kind: .image, file: "x.png", crop: .standard), legibility: 0.6) }
        editor.flush()

        editor.createTheme()

        #expect(editor.draft?.name == "Tema nuevo")
        #expect(editor.draft?.background == nil)
        #expect(editor.draft?.id != Theme.notchyDefault.id)
    }
}
