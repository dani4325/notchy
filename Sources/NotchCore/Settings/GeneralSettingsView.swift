import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(Preferences.Key.nonNotchMode) private var nonNotchMode = NonNotchMode.pill.rawValue
    @AppStorage(Preferences.Key.showCalibrationOutline) private var showOutline = false
    @AppStorage(Preferences.Key.musicSourceMode) private var musicSourceMode = MusicSourceMode.automatic.rawValue
    @AppStorage(Preferences.Key.wingsMode) private var wingsMode = WingsMode.withMusic.rawValue
    @AppStorage(Preferences.Key.chargingAnimation) private var chargingAnimation = true
    @AppStorage(Preferences.Key.volumeHUD) private var volumeHUD = true
    @AppStorage(Preferences.Key.visualizer) private var visualizer = true
    @AppStorage(Preferences.Key.shelf) private var shelfEnabled = true
    @AppStorage(Preferences.Key.shelfLimit) private var shelfLimit = ShelfStore.defaultLimit

    private let nowPlaying: NowPlayingStore
    private let companion: CompanionStore
    private let accessibility: AccessibilityPermission
    private let loginItem: LoginItem
    private let autoThemes: AutoThemeController
    private let themes: ThemeStore
    private let shelf: ShelfStore
    private let updater: SoftwareUpdating?

    init(
        nowPlaying: NowPlayingStore, companion: CompanionStore, accessibility: AccessibilityPermission,
        loginItem: LoginItem, autoThemes: AutoThemeController, themes: ThemeStore, shelf: ShelfStore,
        updater: SoftwareUpdating? = nil
    ) {
        self.updater = updater
        self.shelf = shelf
        self.loginItem = loginItem
        self.autoThemes = autoThemes
        self.themes = themes
        self.nowPlaying = nowPlaying
        self.companion = companion
        self.accessibility = accessibility
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    Toggle("Abrir Notchy al iniciar sesión", isOn: Binding(
                        get: { loginItem.state.isOn },
                        set: { loginItem.setEnabled($0) }
                    ))
                    if loginItem.state == .needsApproval {
                        LabeledContent("Falta tu aprobación") {
                            Button("Abrir Ítems de inicio…", action: loginItem.openSystemSettings)
                        }
                    }
                    if let message = loginItem.message {
                        Text(message).font(.system(size: 11)).foregroundStyle(.red)
                    }
                    if let updater {
                        Toggle("Buscar actualizaciones automáticamente", isOn: Binding(
                            get: { updater.automaticallyChecksForUpdates },
                            set: { updater.automaticallyChecksForUpdates = $0 }
                        ))
                    }
                    Toggle("Animación al conectar o desconectar el cargador", isOn: $chargingAnimation)
                    Toggle("Visualizador de música", isOn: $visualizer)
                    Toggle("Mostrar el volumen en el notch", isOn: $volumeHUD)
                    Toggle("Estantería de archivos", isOn: $shelfEnabled)
                    if shelfEnabled {
                        Stepper(value: Binding(get: { shelfLimit }, set: { shelfLimit = $0; shelf.setLimit($0) }), in: ShelfStore.limitRange) {
                            LabeledContent("Máximo de archivos", value: "\(shelfLimit)")
                        }
                    }
                    if volumeHUD, !accessibility.isTrusted {
                        LabeledContent("Para ocultar el aviso de macOS") {
                            Button("Dar permiso…", action: accessibility.request)
                        }
                    }
                }

                AutoThemeSection(controller: autoThemes, themes: themes)

                Section {
                    Picker("Mostrar alas", selection: $wingsMode) {
                        Text("Siempre").tag(WingsMode.always.rawValue)
                        Text("Solo con música").tag(WingsMode.withMusic.rawValue)
                        Text("Nunca").tag(WingsMode.never.rawValue)
                    }
                    .pickerStyle(.segmented)
                    CompanionSettingsRow(companion: companion)
                    LabeledContent("Ocultar si chocan con menús") {
                        if accessibility.isTrusted {
                            Label("Activo", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Dar permiso…", action: accessibility.request)
                        }
                    }
                } header: {
                    Text("Alas y acompañante")
                } footer: {
                    Text("Las alas muestran la carátula y tu imagen junto al notch. En «Solo con música» se quedan un minuto tras pausar. Los GIF se mueven solo mientras suena música. Con permiso de Accesibilidad se ocultan cuando la app activa tiene menús que llegan al notch.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker("Pantallas sin notch", selection: $nonNotchMode) {
                        Text("Píldora flotante").tag(NonNotchMode.pill.rawValue)
                        Text("Nada").tag(NonNotchMode.hidden.rawValue)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Monitores externos y Macs sin notch.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker("Fuente de música", selection: $musicSourceMode) {
                        Text("Automática").tag(MusicSourceMode.automatic.rawValue)
                        Text("Solo AppleScript").tag(MusicSourceMode.appleScript.rawValue)
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Ahora mismo") {
                        SourceStatusView(source: nowPlaying.activeSource)
                    }
                } footer: {
                    Text("Automática usa MediaRemote (cualquier app, incluido el navegador) y pasa sola a AppleScript (Spotify y Música) si deja de funcionar.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Contorno de calibración", isOn: $showOutline)
                } footer: {
                    Text("Dibuja el borde del panel para comprobar que encaja con el notch.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Text("Now Playing con MediaRemoteAdapter © 2025 Jonas van den Berg y colaboradores · BSD-3-Clause")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}

private struct SourceStatusView: View {
    let source: ActiveMusicSource

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 12, design: .monospaced))
        }
    }

    private var label: String {
        switch source {
        case .checking: String(localized: "comprobando…")
        case .mediaRemote: "MediaRemote"
        case .appleScript(fallback: true): String(localized: "AppleScript (respaldo)")
        case .appleScript(fallback: false): "AppleScript"
        }
    }

    private var color: Color {
        switch source {
        case .checking: .gray
        case .mediaRemote: .green
        case .appleScript(fallback: true): .yellow
        case .appleScript(fallback: false): NotchyStyle.accent
        }
    }
}

private struct CompanionSettingsRow: View {
    let companion: CompanionStore

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let source = companion.source {
                    MediaView(source: source, isActive: true)
                } else {
                    Image(systemName: "sparkle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(NotchyStyle.accent)
                }
            }
            .frame(width: 44, height: 44)
            .background(.black, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(companion.source == nil ? "Destello por defecto" as LocalizedStringKey : "Tu acompañante")
                    .font(.system(size: 13, weight: .semibold))
                if let error = companion.lastError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                } else {
                    Text("Imagen, GIF o vídeo de tu Mac")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if companion.source != nil {
                Button("Quitar", action: companion.clear)
            }
            Button("Elegir…", action: companion.chooseFromPanel)
        }
    }
}
