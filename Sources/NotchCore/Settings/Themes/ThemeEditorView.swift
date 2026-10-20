import AppKit
import SwiftUI

struct ThemeEditorView: View {
    let editor: ThemeEditorModel
    let theme: Theme

    var body: some View {
        if editor.store.isBuiltIn(theme.id) {
            builtInBanner
        }
        Form {
            Section("Nombre") {
                TextField("Nombre del tema", text: editor.binding(\.name, fallback: ""))
            }
            BackgroundSection(editor: editor, theme: theme)
            PaletteSection(editor: editor, theme: theme)
            TypographySection(editor: editor)
            ShapeSection(editor: editor)
            Section("Apertura y efectos") {
                Picker("Animación de apertura", selection: editor.binding(\.openAnimation, fallback: .spring)) {
                    ForEach(OpenAnimation.allCases, id: \.self) { animation in
                        Text(animation.label).tag(animation)
                    }
                }
                Picker("Detalles", selection: editor.binding(\.decoration, fallback: nil)) {
                    Text("Ninguno").tag(ThemeDecoration?.none)
                    ForEach(ThemeDecoration.allCases, id: \.self) { decoration in
                        Text(decoration.label).tag(ThemeDecoration?.some(decoration))
                    }
                }
                LabeledSlider("Brillo de la carátula", value: editor.binding(\.effects.glow, fallback: 0), range: 0...1)
                LabeledSlider("Borde", value: editor.binding(\.effects.borderWidth, fallback: 0), range: 0...3, unit: "pt")
            }
        }
        .formStyle(.grouped)
        .disabled(editor.store.isBuiltIn(theme.id))
    }

    private var builtInBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(NotchyStyle.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Plantilla incluida")
                    .font(.headline)
                Text("Duplícala para añadir tu propia imagen, GIF o vídeo del anime y ajustarla a tu gusto.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Duplicar y personalizar") { editor.duplicate(themeID: theme.id) }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(NotchyStyle.accent.opacity(0.08))
    }
}

extension OpenAnimation {
    var label: String {
        switch self {
        case .spring: String(localized: "Muelle")
        case .bouncy: String(localized: "Rebote")
        case .smooth: String(localized: "Suave")
        case .fade: String(localized: "Fundido")
        case .glitch: String(localized: "Glitch")
        case .gate: String(localized: "Portón")
        case .menacing: String(localized: "ゴゴゴ")
        case .slash: String(localized: "Tajo")
        case .orbit: String(localized: "Órbitas")
        }
    }
}

extension ThemeDecoration {
    var label: String {
        switch self {
        case .nixieTerminal: String(localized: "Nixie y terminal")
        case .wallPlating: String(localized: "Metal y remaches")
        case .menacing: String(localized: "Rayas amenazantes")
        case .reiatsu: String(localized: "Aura y tajo")
        case .orbits: String(localized: "Órbitas y estrellas")
        case .cracks: String(localized: "Grietas")
        case .tacticalGrid: String(localized: "Rejilla táctica")
        case .clovers: String(localized: "Tréboles")
        case .cursedWisps: String(localized: "Volutas de energía")
        case .sawTeeth: String(localized: "Dientes de sierra")
        case .transmutation: String(localized: "Círculo geométrico")
        case .petals: String(localized: "Florecillas")
        case .waves: String(localized: "Olas")
        case .spiral: String(localized: "Espiral")
        case .stationery: String(localized: "Papel de carta")
        case .psychicRings: String(localized: "Anillos psíquicos")
        }
    }
}

private struct BackgroundSection: View {
    let editor: ThemeEditorModel
    let theme: Theme

    var body: some View {
        Section {
            if editor.isMeasuringBackground {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Preparando el fondo…").foregroundStyle(.secondary)
                }
            }
            if let background = theme.background {
                HStack(spacing: 12) {
                    MediaView(
                        source: MediaSource(url: editor.store.mediaURL(themeID: theme.id, media: background.media), kind: background.media.kind),
                        crop: background.media.crop,
                        isActive: false
                    )
                    .frame(width: 132, height: 132 / Self.previewAspect(theme.shape))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(kindLabel(background.media.kind))
                            .font(.headline)
                        HStack {
                            Button("Cambiar…", action: editor.chooseBackground)
                            Button("Quitar", role: .destructive, action: editor.clearBackground)
                        }
                    }
                }
                LabeledSlider("Zoom", value: editor.backgroundBinding(\.media.crop.zoom, fallback: 1), range: MediaCrop.zoomRange, unit: "×")
                LabeledSlider("Posición horizontal", value: editor.backgroundBinding(\.media.crop.focusX, fallback: 0.5), range: 0...1)
                LabeledSlider("Posición vertical", value: editor.backgroundBinding(\.media.crop.focusY, fallback: 0.5), range: 0...1)
                LabeledSlider("Oscurecer más", value: editor.backgroundBinding(\.legibility, fallback: ThemeBackground.defaultLegibility), range: ThemeBackground.legibilityRange)
            } else {
                Button(action: editor.chooseBackground) {
                    Label("Elegir imagen, GIF o vídeo…", systemImage: "photo.on.rectangle.angled")
                }
            }
        } header: {
            Text("Fondo")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Arrastra la imagen en la vista previa para encuadrarla y pellizca para acercarla. El fondo solo se reproduce con el panel abierto.")
                if let kind = theme.background?.media.kind {
                    Text(Self.contrastNote(kind: kind, appearance: ThemeAppearance(theme: theme, background: nil)))
                }
            }
            .settingsFooter()
        }
    }

    private static func contrastNote(kind: MediaKind, appearance: ThemeAppearance) -> LocalizedStringKey {
        guard appearance.colorsReachMinimumOnPanel else {
            return "Con los colores actuales el contraste no está garantizado: algún color no llega al mínimo ni sobre el panel liso."
        }
        switch kind {
        case .image:
            return "Notchy mide la imagen detrás de cada texto y la oscurece lo justo para que el texto llegue a 4,5:1 y las barras e iconos a 3:1. «Oscurecer más» añade oscuridad por encima de ese mínimo."
        case .animatedImage:
            return "Notchy mide todos los fotogramas del GIF detrás de cada texto y los oscurece lo justo para que el texto llegue a 4,5:1 y las barras e iconos a 3:1. «Oscurecer más» añade oscuridad por encima de ese mínimo."
        case .video:
            return "Notchy mide un fotograma del vídeo cada medio segundo y lo oscurece lo justo para que el texto llegue a 4,5:1 y las barras e iconos a 3:1. Entre esos fotogramas el contraste no está garantizado."
        }
    }

    private static func previewAspect(_ shape: ThemeShape) -> CGFloat {
        let layout = IslandLayout(notch: IslandLayout.referenceNotch, shape: shape)
        return layout.size.width / layout.bodyHeight
    }

    private func kindLabel(_ kind: MediaKind) -> String {
        switch kind {
        case .image: String(localized: "Imagen")
        case .animatedImage: String(localized: "Imagen animada")
        case .video: String(localized: "Vídeo en bucle")
        }
    }
}

private struct PaletteSection: View {
    let editor: ThemeEditorModel
    let theme: Theme

    var body: some View {
        Section {
            HStack {
                Text(theme.palette.source == .automatic ? "Automática (del fondo)" as LocalizedStringKey : "Manual")
                    .foregroundStyle(.secondary)
                Spacer()
                if editor.isExtracting {
                    ProgressView().controlSize(.small)
                }
                Button("Extraer del fondo") { editor.extractPalette(force: true) }
                    .disabled(theme.background == nil || editor.isExtracting)
            }
            ColorPicker("Acento", selection: editor.colorBinding(\.accent), supportsOpacity: false)
            ColorPicker("Secundario", selection: editor.colorBinding(\.secondary), supportsOpacity: false)
            ColorPicker("Panel", selection: editor.colorBinding(\.panel), supportsOpacity: false)
            ColorPicker("Texto", selection: editor.colorBinding(\.text), supportsOpacity: false)
            ForEach(editor.contrastIssues, id: \.role) { issue in
                ContrastIssueRow(issue: issue) { editor.applyCorrection(issue) }
            }
        } header: {
            Text("Colores")
        } footer: {
            Text("Al tocar un color la paleta pasa a manual y deja de seguir al fondo.")
                .settingsFooter()
        }
    }
}

private struct ContrastIssueRow: View {
    let issue: PaletteContrastIssue
    let apply: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Usar versión corregida", action: apply)
        }
    }

    private var ratio: String { issue.ratio.formatted(.number.precision(.fractionLength(1))) }

    private var name: String {
        switch issue.role {
        case .accent: String(localized: "El acento")
        case .secondary: String(localized: "El secundario")
        case .text: String(localized: "El texto secundario")
        }
    }

    private var message: LocalizedStringKey {
        if issue.role == .text {
            return "\(name) tiene \(ratio):1 sobre el panel y no llega al mínimo para texto (4,5:1)."
        }
        if issue.failsGraphic {
            return "\(name) tiene \(ratio):1 sobre el panel. No llega al mínimo para texto (4,5:1) ni para barras e iconos (3:1)."
        }
        return "\(name) tiene \(ratio):1 sobre el panel. Sirve para barras e iconos (mínimo 3:1), pero no para texto (mínimo 4,5:1)."
    }
}

private struct TypographySection: View {
    let editor: ThemeEditorModel

    var body: some View {
        Section("Tipografía") {
            Picker("Estilo", selection: editor.binding(\.typography.design, fallback: .rounded)) {
                Text("Sistema").tag(FontDesign.system)
                Text("Redondeada").tag(FontDesign.rounded)
                Text("Serif").tag(FontDesign.serif)
                Text("Monoespaciada").tag(FontDesign.monospaced)
            }
            Picker("Familia", selection: editor.binding(\.typography.family, fallback: nil)) {
                Text("La del estilo").tag(String?.none)
                Divider()
                ForEach(FontCatalog.families, id: \.self) { family in
                    Text(family).tag(String?.some(family))
                }
            }
            Picker("Peso del título", selection: editor.binding(\.typography.titleWeight, fallback: .semibold)) {
                ForEach(FontWeightName.allCases, id: \.self) { weight in
                    Text(weight.label).tag(weight)
                }
            }
        }
    }
}

private struct ShapeSection: View {
    let editor: ThemeEditorModel

    var body: some View {
        Section {
            LabeledSlider("Ancho", value: editor.binding(\.shape.widthRatio, fallback: ThemeShape.standard.widthRatio), range: ThemeShape.widthRange, unit: "×")
            LabeledSlider("Alto del cuerpo", value: editor.binding(\.shape.bodyRatio, fallback: ThemeShape.standard.bodyRatio), range: ThemeShape.bodyRange, unit: "×")
            LabeledSlider("Esquinas superiores", value: editor.binding(\.shape.bodyTopRadiusRatio, fallback: ThemeShape.standard.bodyTopRadiusRatio), range: ThemeShape.radiusRange, unit: "×")
            LabeledSlider("Esquinas inferiores", value: editor.binding(\.shape.bottomRadiusRatio, fallback: ThemeShape.standard.bottomRadiusRatio), range: ThemeShape.radiusRange, unit: "×")
            LabeledSlider("Unión con el notch", value: editor.binding(\.shape.junctionRatio, fallback: ThemeShape.standard.junctionRatio), range: ThemeShape.junctionRange, unit: "×")
        } header: {
            Text("Forma del panel")
        } footer: {
            Text("Las medidas son proporciones del notch, así que el panel se ve igual en cualquier MacBook.")
                .settingsFooter()
        }
    }
}

private struct LabeledSlider: View {
    let title: LocalizedStringKey
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let unit: String
    let step: Double?

    init(_ title: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>, unit: String = "", step: Double? = nil) {
        self.title = title
        self.value = value
        self.range = range
        self.unit = unit
        self.step = step
    }

    var body: some View {
        LabeledContent(title) {
            HStack {
                if let step {
                    Slider(value: value, in: range, step: step)
                } else {
                    Slider(value: value, in: range)
                }
                Text(formatted)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    private var formatted: String {
        let number = range.upperBound <= 8 ? String(format: "%.2f", value.wrappedValue) : String(format: "%.0f", value.wrappedValue)
        return number + unit
    }
}

@MainActor
private enum FontCatalog {
    static let families = NSFontManager.shared.availableFontFamilies.sorted()
}

private extension FontWeightName {
    var label: String {
        switch self {
        case .regular: String(localized: "Normal")
        case .medium: String(localized: "Media")
        case .semibold: String(localized: "Seminegrita")
        case .bold: String(localized: "Negrita")
        case .heavy: String(localized: "Gruesa")
        case .black: String(localized: "Extragruesa")
        }
    }
}
