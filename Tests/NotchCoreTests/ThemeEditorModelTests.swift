import AppKit
import SwiftUI
import Testing
@testable import NotchCore

@MainActor
struct ThemeEditorModelTests {
    let store = ThemeStore(
        directory: FileManager.default.temporaryDirectory.appendingPathComponent("notchy-editor-\(UUID().uuidString)"),
        defaults: UserDefaults(suiteName: "notchy-editor-\(UUID().uuidString)")!,
        trash: FakeTrash(root: FileManager.default.temporaryDirectory.appendingPathComponent("notchy-editor-trash-\(UUID().uuidString)")).move
    )

    @Test func deletingMovesToTheTrashAndOffersUndo() throws {
        let editor = ThemeEditorModel(store: store)
        let theme = try store.createTheme(named: "Para borrar")

        editor.delete(themeID: theme.id)

        #expect(store.theme(id: theme.id) == nil)
        #expect(editor.undoableDeletion?.name == "Para borrar")

        editor.undoDeletion()

        #expect(store.theme(id: theme.id) != nil)
        #expect(editor.undoableDeletion == nil)
        #expect(editor.draft?.id == theme.id)
    }

    @Test func builtInThemesAreNotDeleted() throws {
        let editor = ThemeEditorModel(store: store)
        let builtIn = try #require(Theme.builtIns.first)

        editor.delete(themeID: builtIn.id)

        #expect(store.theme(id: builtIn.id) != nil)
        #expect(editor.undoableDeletion == nil)
    }

    @Test func importedGIFBackgroundsBecomeMeasuredVideos() async throws {
        let editor = ThemeEditorModel(store: store)
        let theme = try store.createTheme(named: "Con GIF")
        let gif = try GIFTranscoderTests().makeGIF(transparent: false)

        await editor.applyBackground(from: gif, themeID: theme.id)

        let media = try #require(store.theme(id: theme.id)?.background?.media)
        #expect(media.kind == .video)
        #expect(store.measurement(themeID: theme.id) != nil)
    }

    @Test func importedGIFCompanionsBecomeVideos() async throws {
        let companion = CompanionStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent("companion-\(UUID().uuidString)"),
            defaults: UserDefaults(suiteName: "companion-\(UUID().uuidString)")!
        )
        let gif = try GIFTranscoderTests().makeGIF(transparent: true)

        await companion.importConvertingGIFs(from: gif)

        #expect(companion.source?.kind == .video)
        #expect(companion.lastError == nil)
    }

    @Test func aManualAccentThatFailsShowsAWarningUntilTheCorrectionIsApplied() throws {
        let editor = ThemeEditorModel(store: store)
        let theme = try store.createTheme(named: "Colores")
        editor.select(themeID: theme.id)

        editor.colorBinding(\.accent).wrappedValue = Color(.sRGB, red: 0x1E / 255, green: 0x3A / 255, blue: 0xFF / 255)

        let issue = try #require(editor.contrastIssues.first { $0.role == .accent })
        editor.applyCorrection(issue)

        #expect(editor.contrastIssues.contains { $0.role == .accent } == false)
        #expect(editor.draft?.palette.source == .manual)
    }

    @Test func storeErrorsBecomeMessagesThatSayWhatHappened() {
        let fallback = "No se ha podido crear el tema."

        #expect(ThemeEditorModel.describe(ThemeStore.StoreError.mediaTooLarge, fallback: fallback).contains("200 MB"))
        #expect(ThemeEditorModel.describe(ThemeStore.StoreError.writeFailed, fallback: fallback).hasPrefix(fallback))
        #expect(ThemeEditorModel.describe(CocoaError(.fileNoSuchFile), fallback: fallback) == fallback)
    }

    @Test func deletingTheLastOwnThemeShowsTheDefault() throws {
        let editor = ThemeEditorModel(store: store)
        let theme = try store.createTheme(named: "Único")
        store.activate(themeID: theme.id)
        editor.select(themeID: theme.id)

        editor.delete(themeID: theme.id)

        #expect(editor.messageIsError == false)
        #expect(editor.draft?.id == Theme.notchyDefault.id)
    }

    @Test func startsEditingTheActiveTheme() {
        let editor = ThemeEditorModel(store: store)

        #expect(editor.draft?.id == store.activeTheme.id)
    }

    @Test func editsChangeTheDraftAndPersistOnFlush() throws {
        let theme = try store.createTheme(named: "Propio")
        store.activate(themeID: theme.id)
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
        let theme = try store.createTheme(named: "Propio")
        let copy = try store.duplicate(themeID: theme.id)
        editor.select(themeID: theme.id)
        editor.update { $0.name = "Guardado al cambiar" }

        editor.select(themeID: copy.id)

        #expect(store.theme(id: theme.id)?.name == "Guardado al cambiar")
        #expect(editor.draft?.id == copy.id)
    }

    @Test func searchQueryFiltersThemesIgnoringCaseAndDiacritics() throws {
        let editor = ThemeEditorModel(store: store)
        _ = try store.createTheme(named: "Fósforo nocturno")
        _ = try store.createTheme(named: "Cobalto")

        #expect(editor.filteredThemes.count == store.themes.count)

        editor.searchQuery = "  fosforo "
        #expect(editor.filteredThemes.contains { $0.name == "Fósforo nocturno" })
        #expect(editor.filteredThemes.contains { $0.name == "Cobalto" } == false)

        editor.searchQuery = ""
        #expect(editor.filteredThemes.count == store.themes.count)
    }

    @Test func mediaImageCacheDownsamplesLargeImages() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-downsample-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1600, pixelsHigh: 800,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let data = try #require(rep.representation(using: .png, properties: [:]))
        try data.write(to: url)

        let image = try #require(MediaImageCache.image(at: url, maxPixelSize: 400))
        let maxSide = max(image.size.width, image.size.height)
        #expect(maxSide <= 400)
        #expect(maxSide >= 200)
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
