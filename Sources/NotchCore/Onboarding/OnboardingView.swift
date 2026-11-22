import SwiftUI

public struct OnboardingView: View {
    private let model: OnboardingModel
    private let accessibility: AccessibilityPermission
    private let loginItem: LoginItem
    private let themes: ThemeStore

    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: OnboardingModel, accessibility: AccessibilityPermission, loginItem: LoginItem, themes: ThemeStore) {
        self.model = model
        self.accessibility = accessibility
        self.loginItem = loginItem
        self.themes = themes
    }

    public var body: some View {
        VStack(spacing: 0) {
            StepDots(current: model.step)
                .padding(.top, 22)
            Group {
                switch model.step {
                case .welcome: WelcomeStep(themes: themes)
                case .permissions: PermissionsStep(accessibility: accessibility, loginItem: loginItem)
                case .theme: ThemeStep(themes: themes)
                case .tryIt: TryStep(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 36)
            .transition(.opacity)
            .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: model.step)

            HStack {
                if model.step != .welcome {
                    Button("Atrás", action: model.back)
                }
                Spacer()
                if model.step == .permissions {
                    Button("Saltar", action: model.next)
                        .buttonStyle(.borderless)
                }
                Button(model.isLastStep ? "Empezar" : "Siguiente") {
                    if model.isLastStep {
                        model.finish()
                        dismissWindow(id: OnboardingModel.windowID)
                    } else {
                        model.next()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 640, height: 500)
        .containerBackground(.thickMaterial, for: .window)
        .tint(NotchyStyle.accent)
    }
}

private struct StepDots: View {
    let current: OnboardingStep

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step == current ? AnyShapeStyle(NotchyStyle.accent) : AnyShapeStyle(.quaternary))
                    .frame(width: step == current ? 22 : 8, height: 8)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: current)
        .accessibilityHidden(true)
    }
}

private struct WelcomeStep: View {
    let themes: ThemeStore

    var body: some View {
        VStack(spacing: 24) {
            PanelPreview(themes: themes)
            VStack(spacing: 10) {
                Text("Tu notch, a tu manera")
                    .font(.largeTitle.bold())
                Text("Muestra la canción que suena con sus controles, guarda los archivos que arrastras al notch y avisa del cargador y del volumen.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
        }
    }
}

private struct PanelPreview: View {
    let themes: ThemeStore

    private static let scale: CGFloat = 0.8
    private static let sample = NowPlayingInfo(
        title: String(localized: "Canción de ejemplo"), artist: String(localized: "Tu artista favorito"), album: nil, duration: 214,
        elapsed: 71, timestamp: .now, playbackRate: 0, isPlaying: false, appBundleID: "", artworkData: nil
    )

    var body: some View {
        let theme = themes.activeTheme
        let appearance = ThemeAppearance.resolve(theme, in: themes)
        let model = IslandModel(kind: .notch, collapsedSize: IslandLayout.referenceNotch, stripHeight: IslandLayout.referenceNotch.height)
        model.shapeStyle = theme.shape
        model.state = .expanded
        let size = model.currentSize
        let layout = model.layout

        return ZStack(alignment: .top) {
            IslandSurface(model: model, appearance: appearance, showOutline: false)
            ExpandedMusicView(layout: layout, info: Self.sample, artwork: nil, appName: nil, controls: .inert)
                .allowsHitTesting(false)
                .padding(.top, layout.stem.height)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .environment(\.themeAppearance, appearance)
        .scaleEffect(Self.scale, anchor: .top)
        .frame(width: size.width * Self.scale, height: size.height * Self.scale, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vista previa del panel con una canción de ejemplo")
    }
}

private struct PermissionsStep: View {
    let accessibility: AccessibilityPermission
    let loginItem: LoginItem

    @AppStorage(Preferences.Key.audioCaptureConfirmed) private var audioConfirmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Permisos")
                .font(.title.bold())
            Text("Todos son opcionales. Puedes darlos ahora o más tarde desde Ajustes.")
                .font(.body)
                .foregroundStyle(.secondary)
            PermissionRow(
                symbol: "hand.raised",
                title: "Accesibilidad",
                detail: "Oculta las alas cuando chocan con los menús y sustituye el aviso de volumen de macOS.",
                isGranted: accessibility.isTrusted
            ) {
                Button("Dar permiso", action: accessibility.request)
            }
            PermissionRow(
                symbol: "waveform",
                title: "Audio del sistema",
                detail: "Anima el visualizador con la música que suena. No graba ni guarda nada. Se marca como concedido cuando Notchy recibe audio por primera vez.",
                isGranted: audioConfirmed,
                pendingStatus: "Sin comprobar"
                ) {
                Button("Pedir permiso", action: AudioVisualizer.requestPermission)
                Button("Abrir Ajustes", action: AudioVisualizer.openCaptureSettings)
            }
            PermissionRow(
                symbol: "power",
                title: "Abrir al iniciar sesión",
                detail: "Notchy arranca solo cuando entras en tu Mac.",
                isGranted: loginItem.state.isOn
            ) {
                Button("Activar") { loginItem.setEnabled(true) }
            }
            Text("Si algún día falla la lectura de la música, macOS te pedirá permiso para controlar Spotify o Música.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PermissionRow<Actions: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let isGranted: Bool
    var pendingStatus: LocalizedStringKey?
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if isGranted {
                Label("Concedido", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                HStack {
                    if let pendingStatus {
                        Text(pendingStatus).foregroundStyle(.secondary)
                    }
                    actions()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ThemeStep: View {
    let themes: ThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Elige tu tema")
                .font(.title.bold())
            Text("Puedes cambiarlo cuando quieras y añadir tus propias imágenes, GIF o vídeos.")
                .font(.body)
                .foregroundStyle(.secondary)
            List(selection: Binding(
                get: { themes.activeThemeID as String? },
                set: { if let id = $0 { themes.activate(themeID: id) } }
            )) {
                ForEach(themes.themes) { theme in
                    ThemeChip(theme: theme, isActive: themes.activeThemeID == theme.id)
                        .tag(theme.id as String?)
                }
            }
            .listStyle(.sidebar)
        }
    }
}

private struct ThemeChip: View {
    let theme: Theme
    let isActive: Bool

    var body: some View {
        let appearance = ThemeAppearance(theme: theme, background: nil)
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(PaletteSwatchRole.allCases, id: \.self) { role in
                    Circle().fill(appearance.color(for: role)).frame(width: 8, height: 8)
                }
            }
            .padding(6)
            .background(appearance.panel, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityHidden(true)
            Text(theme.name)
                .font(appearance.titleFont(13))
                .lineLimit(1)
            Spacer()
            if isActive {
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct TryStep: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 18) {
            Text("Pruébalo")
                .font(.largeTitle.bold())
            Text("Pasa el ratón por el notch para abrir el panel. Arrastra archivos hasta él para guardarlos en la estantería.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Abrir el panel ahora", action: model.tryPanel)
                .controlSize(.large)
        }
    }
}
