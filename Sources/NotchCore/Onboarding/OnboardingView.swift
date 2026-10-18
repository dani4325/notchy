import SwiftUI

public struct OnboardingView: View {
    private let model: OnboardingModel
    private let accessibility: AccessibilityPermission
    private let loginItem: LoginItem
    private let themes: ThemeStore

    @Environment(\.dismissWindow) private var dismissWindow

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
                case .welcome: WelcomeStep()
                case .permissions: PermissionsStep(accessibility: accessibility, loginItem: loginItem)
                case .theme: ThemeStep(themes: themes)
                case .tryIt: TryStep(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 36)
            .transition(.opacity)
            .animation(.smooth(duration: 0.25), value: model.step)

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
        .background(
            LinearGradient(colors: [Color(white: 0.12), Color(white: 0.06)], startPoint: .top, endPoint: .bottom)
        )
        .environment(\.colorScheme, .dark)
        .tint(NotchyStyle.accent)
    }
}

private struct StepDots: View {
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step == current ? NotchyStyle.accent : Color.white.opacity(0.2))
                    .frame(width: step == current ? 22 : 8, height: 8)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityHidden(true)
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 22) {
            NotchSketch()
                .frame(width: 300, height: 110)
            VStack(spacing: 8) {
                Text("Tu notch, a tu manera")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                Text("Notchy convierte el notch en un panel vivo con tu música, tus temas y tus archivos.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(alignment: .top, spacing: 18) {
                Feature(symbol: "music.note", title: "Música", detail: "Carátula, controles y visualizador")
                Feature(symbol: "paintpalette", title: "Temas", detail: "Plantillas de anime y tus propias imágenes")
                Feature(symbol: "tray.full", title: "Estantería", detail: "Deja archivos en el notch")
            }
        }
    }
}

private struct Feature: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(NotchyStyle.accent)
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 150)
    }
}

private struct NotchSketch: View {
    var body: some View {
        let layout = IslandLayout(notch: CGSize(width: 110, height: 22), shape: .standard)
        layout.islandShape
            .fill(.black)
            .overlay(layout.islandShape.stroke(NotchyStyle.accent.opacity(0.6), lineWidth: 1))
            .frame(width: layout.size.width, height: layout.size.height)
            .shadow(color: NotchyStyle.accent.opacity(0.35), radius: 18)
            .accessibilityHidden(true)
    }
}

private struct PermissionsStep: View {
    let accessibility: AccessibilityPermission
    let loginItem: LoginItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Permisos")
                .font(.system(size: 24, weight: .black, design: .rounded))
            Text("Todos son opcionales. Puedes darlos ahora o más tarde desde Ajustes.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            PermissionRow(
                symbol: "hand.raised",
                title: "Accesibilidad",
                detail: "Oculta las alas cuando chocan con los menús y sustituye el aviso de volumen de macOS.",
                isGranted: accessibility.isTrusted,
                action: accessibility.request
            )
            PermissionRow(
                symbol: "waveform",
                title: "Audio del sistema",
                detail: "Anima el visualizador con la música que suena. No graba ni guarda nada.",
                isGranted: false,
                action: AudioVisualizer.requestPermission
            )
            PermissionRow(
                symbol: "power",
                title: "Abrir al iniciar sesión",
                detail: "Notchy arranca solo cuando entras en tu Mac.",
                isGranted: loginItem.state.isOn,
                buttonTitle: "Activar",
                action: { loginItem.setEnabled(true) }
            )
            Text("Si algún día falla la lectura de la música, macOS te pedirá permiso para controlar Spotify o Música.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PermissionRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let isGranted: Bool
    var buttonTitle: LocalizedStringKey = "Dar permiso"
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(NotchyStyle.accent)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if isGranted {
                Label("Concedido", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Concedido")
            } else {
                Button(buttonTitle, action: action)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ThemeStep: View {
    let themes: ThemeStore

    private let columns = [GridItem(.adaptive(minimum: 128), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Elige tu tema")
                .font(.system(size: 24, weight: .black, design: .rounded))
            Text("Puedes cambiarlo cuando quieras y añadir tus propias imágenes, GIF o vídeos.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(themes.themes) { theme in
                        ThemeChip(theme: theme, isActive: themes.activeThemeID == theme.id)
                            .onTapGesture { themes.activate(themeID: theme.id) }
                    }
                }
            }
        }
    }
}

private struct ThemeChip: View {
    let theme: Theme
    let isActive: Bool

    var body: some View {
        let appearance = ThemeAppearance(theme: theme, background: nil)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach([appearance.accent, appearance.secondary, appearance.text], id: \.self) { color in
                    Circle().fill(color).frame(width: 9, height: 9)
                }
                Spacer()
                if let emblem = theme.emblem {
                    EmblemView(emblem: emblem, size: 22, appearance: appearance)
                }
            }
            Text(theme.name)
                .font(.custom(theme.typography.family ?? "", size: 12).weight(.semibold))
                .foregroundStyle(appearance.text)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
        }
        .padding(10)
        .background(LinearGradient(colors: [.black, appearance.panel], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(isActive ? NotchyStyle.accent : Color.white.opacity(0.1), lineWidth: isActive ? 2 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

private struct TryStep: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(NotchyStyle.accent)
            Text("Pruébalo")
                .font(.system(size: 26, weight: .black, design: .rounded))
            Text("Pasa el ratón por el notch para abrir el panel. Arrastra archivos hasta él para guardarlos en la estantería.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Abrir el panel ahora", systemImage: "sparkles", action: model.tryPanel)
                .controlSize(.large)
        }
    }
}
