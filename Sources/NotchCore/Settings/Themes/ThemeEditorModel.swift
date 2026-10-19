import AppKit
import Observation
import os
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
public final class ThemeEditorModel {
    public private(set) var draft: Theme?
    public private(set) var undoableDeletion: Theme?
    @ObservationIgnored private var trashedFolder: URL?
    public private(set) var message: String?
    public private(set) var isExtracting = false
    public private(set) var isMeasuringBackground = false
    public private(set) var backgroundAspect: Double?
    let previewModel: IslandModel

    @ObservationIgnored let store: ThemeStore
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var isDirty = false
    @ObservationIgnored private var dragOrigin: MediaCrop?
    @ObservationIgnored private var zoomOrigin: Double?
    @ObservationIgnored private var aspectTask: Task<Void, Never>?

    private static let saveDelay: Duration = .milliseconds(350)
    private static let paletteClusters = 6
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "editor")
    static let archiveType = UTType(filenameExtension: ThemeArchive.fileExtension) ?? .zip

    public init(store: ThemeStore) {
        self.store = store
        let notch = NotchGeometry.primaryNotchSize
        previewModel = IslandModel(kind: .notch, collapsedSize: notch, stripHeight: notch.height)
        previewModel.state = .expanded
        select(themeID: store.activeThemeID)
    }

    public var isEditingActiveTheme: Bool {
        draft?.id == store.activeThemeID
    }

    public func select(themeID: String) {
        flush()
        draft = store.theme(id: themeID)
        message = nil
        syncPreview()
        loadBackgroundAspect()
    }

    public func dragBackground(by translation: CGSize, displayedSize: CGSize) {
        guard let crop = draft?.background?.media.crop else { return }
        let origin = dragOrigin ?? crop
        dragOrigin = origin
        let moved = origin.dragged(by: translation, displayedSize: displayedSize, mediaAspect: backgroundAspect ?? 1)
        update { $0.background?.media.crop = moved }
    }

    public func endBackgroundDrag() {
        dragOrigin = nil
    }

    public func zoomBackground(by magnification: Double) {
        guard let zoom = draft?.background?.media.crop.zoom else { return }
        let origin = zoomOrigin ?? zoom
        zoomOrigin = origin
        update { $0.background?.media.crop.zoom = (origin * magnification).clamped(to: MediaCrop.zoomRange) }
    }

    public func endBackgroundZoom() {
        zoomOrigin = nil
    }

    private func loadBackgroundAspect() {
        aspectTask?.cancel()
        backgroundAspect = nil
        guard let theme = draft, let background = theme.background else { return }
        let url = store.mediaURL(themeID: theme.id, media: background.media)
        aspectTask = Task { [weak self] in
            guard let frame = await PaletteExtractor.firstFrame(of: url, kind: background.media.kind),
                  !Task.isCancelled, frame.height > 0
            else { return }
            self?.backgroundAspect = Double(frame.width) / Double(frame.height)
        }
    }

    public func update(_ change: (inout Theme) -> Void) {
        guard var theme = draft else { return }
        change(&theme)
        draft = theme
        syncPreview()
        scheduleSave()
    }

    public func setColor(_ keyPath: WritableKeyPath<ThemePalette, HexColor>, to color: HexColor) {
        update {
            $0.palette[keyPath: keyPath] = color
            $0.palette.source = .manual
        }
    }

    func applyExtracted(_ palette: ThemePalette, force: Bool) {
        guard force || draft?.palette.source == .automatic else { return }
        update { $0.palette = palette }
    }

    public func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard isDirty, let draft else { return }
        isDirty = false
        do {
            try store.save(draft)
        } catch {
            message = String(localized: "No se ha podido guardar el tema.")
        }
    }

    public func binding<Value>(_ keyPath: WritableKeyPath<Theme, Value>, fallback: Value) -> Binding<Value> {
        Binding(
            get: { [weak self] in self?.draft?[keyPath: keyPath] ?? fallback },
            set: { [weak self] value in self?.update { $0[keyPath: keyPath] = value } }
        )
    }

    public func backgroundBinding<Value>(_ keyPath: WritableKeyPath<ThemeBackground, Value>, fallback: Value) -> Binding<Value> {
        Binding(
            get: { [weak self] in self?.draft?.background?[keyPath: keyPath] ?? fallback },
            set: { [weak self] value in
                guard self?.draft?.background != nil else { return }
                self?.update { $0.background?[keyPath: keyPath] = value }
            }
        )
    }

    public func colorBinding(_ keyPath: WritableKeyPath<ThemePalette, HexColor>) -> Binding<Color> {
        Binding(
            get: { [weak self] in Color(self?.draft?.palette[keyPath: keyPath] ?? Theme.notchyDefault.palette.accent) },
            set: { [weak self] color in
                guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
                let rgb = RGB(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent)
                self?.setColor(keyPath, to: HexColor(rgb: rgb))
            }
        )
    }

    public func activate() {
        guard let draft else { return }
        flush()
        store.activate(themeID: draft.id)
    }

    public func createTheme() {
        flush()
        perform(String(localized: "No se ha podido crear el tema.")) {
            select(themeID: try store.createTheme(named: String(localized: "Tema nuevo")).id)
        }
    }

    public func duplicate(themeID: String) {
        flush()
        perform(String(localized: "No se ha podido duplicar el tema.")) {
            select(themeID: try store.duplicate(themeID: themeID).id)
        }
    }

    public func undoDeletion() {
        guard let theme = undoableDeletion, let trashed = trashedFolder else { return }
        undoableDeletion = nil
        trashedFolder = nil
        perform(String(localized: "No se ha podido recuperar el tema de la Papelera.")) {
            try store.restore(themeID: theme.id, from: trashed)
            select(themeID: theme.id)
        }
    }

    public func delete(themeID: String) {
        guard !store.isBuiltIn(themeID), let theme = store.theme(id: themeID) else { return }
        flush()
        perform(String(localized: "No se puede borrar el único tema que queda.")) {
            trashedFolder = try store.delete(themeID: themeID)
            undoableDeletion = theme
            if draft?.id == themeID {
                select(themeID: store.activeThemeID)
            }
        }
    }

    public func chooseBackground() {
        guard let themeID = draft?.id else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.message = String(localized: "Elige una imagen, un GIF o un vídeo para el fondo del panel")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        flush()
        Task { await applyBackground(from: url, themeID: themeID) }
    }

    func applyBackground(from url: URL, themeID: String) async {
        guard let kind = try? MediaKind.detect(at: url) else {
            message = String(localized: "Ese archivo no se puede usar como fondo.")
            return
        }
        isMeasuringBackground = true
        let measurement = await BackgroundMeasurer.measureInBackground(url, kind: kind)
        isMeasuringBackground = false
        guard let measurement else {
            message = String(localized: "No se ha podido medir el fondo para garantizar el contraste. Prueba con otro archivo.")
            return
        }
        perform(String(localized: "Ese archivo no se puede usar como fondo.")) {
            let updated = try store.setBackground(from: url, themeID: themeID, measurement: measurement)
            guard draft?.id == themeID else { return }
            draft = updated
            syncPreview()
            loadBackgroundAspect()
            extractPalette(force: false)
        }
    }

    public func clearBackground() {
        guard let themeID = draft?.id else { return }
        flush()
        perform(String(localized: "No se ha podido quitar el fondo.")) {
            draft = try store.clearBackground(themeID: themeID)
            syncPreview()
        }
    }

    public func extractPalette(force: Bool) {
        guard let theme = draft, let background = theme.background else { return }
        let url = store.mediaURL(themeID: theme.id, media: background.media)
        isExtracting = true
        Task { [weak self] in
            let frame = await PaletteExtractor.firstFrame(of: url, kind: background.media.kind)
            let clusters = frame.map { PaletteExtractor.clusters(from: $0, count: Self.paletteClusters) } ?? []
            guard let self else { return }
            self.isExtracting = false
            guard self.draft?.id == theme.id, !clusters.isEmpty else {
                if clusters.isEmpty { self.message = String(localized: "No se han podido leer los colores del fondo.") }
                return
            }
            self.applyExtracted(PaletteBuilder.palette(from: clusters), force: force)
        }
    }

    public func exportTheme(themeID: String) {
        guard let theme = store.theme(id: themeID) else { return }
        flush()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [Self.archiveType]
        panel.nameFieldStringValue = "\(theme.name).\(ThemeArchive.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url,
              let (payload, media) = try? store.exportPayload(themeID: themeID)
        else { return }
        Task { [weak self] in
            do {
                try await Task.detached(priority: .userInitiated) {
                    try ThemeStore.writeArchive(theme: payload, mediaURL: media, to: url)
                }.value
                self?.message = String(localized: "Tema exportado.")
            } catch {
                Self.logger.error("export failed: \(String(describing: error), privacy: .public)")
                self?.message = String(localized: "No se ha podido exportar el tema.")
            }
        }
    }

    public func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [Self.archiveType]
        panel.message = String(localized: "Elige un archivo .\(ThemeArchive.fileExtension)")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await importTheme(from: url) }
    }

    @discardableResult
    public func importTheme(from url: URL) async -> Bool {
        flush()
        let destination = store.importDestination()
        do {
            let staged = try await Task.detached(priority: .userInitiated) {
                try ThemeStore.stageImport(archive: url, into: destination.folder)
            }.value
            let theme = try store.finishImport(staged, id: destination.id)
            select(themeID: theme.id)
            message = String(localized: "Tema «\(theme.name)» importado.")
            Task { await store.measureMissing() }
            return true
        } catch {
            Self.logger.error("import failed: \(String(describing: error), privacy: .public)")
            try? FileManager.default.removeItem(at: destination.folder)
            message = String(localized: "Ese archivo no es un tema válido de Notchy.")
            return false
        }
    }

    public func replayOpening() {
        guard let draft else { return }
        let policy = MotionPolicy.current(openAnimation: draft.openAnimation)
        previewModel.state = .compact
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self else { return }
            self.previewModel.reduceMotion = policy.reduceMotion
            self.previewModel.openCount += 1
            withAnimation(policy.shapeAnimation(expanding: true)) {
                self.previewModel.state = .expanded
            }
        }
    }

    private func syncPreview() {
        guard let draft else { return }
        previewModel.shapeStyle = draft.shape
        previewModel.openAnimation = draft.openAnimation
    }

    private func scheduleSave() {
        isDirty = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    private func perform(_ failure: String, _ action: () throws -> Void) {
        do {
            try action()
        } catch {
            Self.logger.error("\(failure, privacy: .public): \(String(describing: error), privacy: .public)")
            message = failure
        }
    }
}
