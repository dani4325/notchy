import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(Preferences.Key.nonNotchMode) private var nonNotchMode = NonNotchMode.pill.rawValue
    @AppStorage(Preferences.Key.showCalibrationOutline) private var showOutline = false
    @AppStorage(Preferences.Key.musicSourceMode) private var musicSourceMode = MusicSourceMode.automatic.rawValue
    @AppStorage(Preferences.Key.wingsMode) private var wingsMode = WingsMode.withMusic.rawValue
    @AppStorage(Preferences.Key.chargingAnimation) private var chargingAnimation = true
    @AppStorage(Preferences.Key.volumeHUD) private var volumeHUD = true
    @AppStorage(Preferences.Key.visualizer) private var visualizer = true
    @AppStorage(Preferences.Key.audioCaptureConfirmed) private var audioConfirmed = false
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
    private let showWelcome: () -> Void

    init(
        nowPlaying: NowPlayingStore, companion: CompanionStore, accessibility: AccessibilityPermission,
        loginItem: LoginItem, autoThemes: AutoThemeController, themes: ThemeStore, shelf: ShelfStore,
        updater: SoftwareUpdating? = nil, showWelcome: @escaping () -> Void = {}
    ) {
        self.updater = updater
        self.showWelcome = showWelcome
        self.shelf = shelf
        self.loginItem = loginItem
        self.autoThemes = autoThemes
        self.themes = themes
        self.nowPlaying = nowPlaying
        self.companion = companion
        self.accessibility = accessibility
    }

    var body: some View {
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
                    Text(message).font(.callout).foregroundStyle(.red)
                }
                if let updater {
                    Toggle("Buscar actualizaciones automáticamente", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))
                }
                Toggle("Animación al conectar o desconectar el cargador", isOn: $chargingAnimation)
                Toggle("Visualizador de música", isOn: $visualizer)
                if visualizer {
                    LabeledContent("Audio del sistema") {
                        if audioConfirmed {
                            Label("Concedido", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            HStack {
                                Text("Sin comprobar").foregroundStyle(.secondary)
                                Button("Pedir permiso", action: AudioVisualizer.requestPermission)
                                Button("Abrir Ajustes", action: AudioVisualizer.openCaptureSettings)
                            }
                        }
                    }
                }
                Toggle("Mostrar el volumen en el notch", isOn: $volumeHUD)
                Toggle("Estantería de archivos", isOn: $shelfEnabled)
                if shelfEnabled {
                    Stepper(value: Binding(get: { shelfLimit }, set: { shelfLimit = $0; shelf.setLimit($0) }), in: ShelfStore.limitRange) {
                        LabeledContent("Máximo de archivos", value: "\(shelfLimit)")
                    }
                    if let problem = shelf.lastError {
                        Text(problem).font(.callout).foregroundStyle(.red)
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
                Text("Las alas muestran la carátula y tu imagen junto al notch. En «Solo con música» se quedan un minuto tras pausar. Los GIF y vídeos se mueven solo mientras suena música. Con permiso de Accesibilidad se ocultan cuando la app activa tiene menús que llegan al notch.")
                    .settingsFooter()
            }

            Section {
                Picker("Pantallas sin notch", selection: $nonNotchMode) {
                    Text("Píldora flotante").tag(NonNotchMode.pill.rawValue)
                    Text("Nada").tag(NonNotchMode.hidden.rawValue)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Monitores externos y Macs sin notch.")
                    .settingsFooter()
            }

            Section {
                Picker("Fuente de música", selection: $musicSourceMode) {
                    Text("Cualquier app").tag(MusicSourceMode.automatic.rawValue)
                    Text("Solo Spotify y Música").tag(MusicSourceMode.appleScript.rawValue)
                }
                .pickerStyle(.segmented)
                LabeledContent("Ahora mismo") {
                    SourceStatusView(source: nowPlaying.activeSource)
                }
            } footer: {
                Text("«Cualquier app» lee lo que suena en cualquier reproductor, también en el navegador. Si deja de funcionar, Notchy pasa sola a leer Spotify y Música.")
                    .settingsFooter()
            }

            Section {
                Toggle("Contorno de calibración", isOn: $showOutline)
            } footer: {
                Text("Dibuja el borde del panel para comprobar que encaja con el notch.")
                    .settingsFooter()
            }

            Section {
                LabeledContent("Versión", value: AppInfo.version)
                LabeledContent("Bienvenida") {
                    Button("Ver de nuevo", action: showWelcome)
                }
            } footer: {
                Text("Lectura de la música con MediaRemoteAdapter © 2025 Jonas van den Berg y colaboradores, licencia BSD-3-Clause.")
                    .settingsFooter()
            }
        }
        .formStyle(.grouped)
    }
}

private struct SourceStatusView: View {
    let source: ActiveMusicSource

    var body: some View {
        Label(label, systemImage: symbol)
    }

    private var label: String {
        switch source {
        case .checking: String(localized: "Comprobando…")
        case .mediaRemote: String(localized: "Cualquier app")
        case .appleScript(fallback: true): String(localized: "Solo Spotify y Música, porque la lectura general falló")
        case .appleScript(fallback: false): String(localized: "Solo Spotify y Música")
        }
    }

    private var symbol: String {
        switch source {
        case .checking: "hourglass"
        case .mediaRemote: "checkmark.circle"
        case .appleScript(fallback: true): "exclamationmark.triangle"
        case .appleScript(fallback: false): "music.note"
        }
    }
}

private struct CompanionSettingsRow: View {
    let companion: CompanionStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let source = companion.source {
                    MediaView(source: source, isActive: !reduceMotion)
                    } else {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 44, height: 44)
            .background(.black, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(companion.source == nil ? "Sin acompañante" as LocalizedStringKey : "Tu acompañante")
                    .font(.headline)
                if let error = companion.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                } else {
                    Text("Imagen, GIF o vídeo de tu Mac")
                        .font(.callout)
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
