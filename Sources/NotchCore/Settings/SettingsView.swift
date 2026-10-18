import SwiftUI

public struct SettingsView: View {
    @AppStorage(Preferences.Key.nonNotchMode) private var nonNotchMode = NonNotchMode.pill.rawValue
    @AppStorage(Preferences.Key.showCalibrationOutline) private var showOutline = false
    @AppStorage(Preferences.Key.musicSourceMode) private var musicSourceMode = MusicSourceMode.automatic.rawValue
    @AppStorage(Preferences.Key.wingsMode) private var wingsMode = WingsMode.withMusic.rawValue

    private let nowPlaying: NowPlayingStore
    private let companion: CompanionStore
    private let accessibility: AccessibilityPermission

    public init(nowPlaying: NowPlayingStore, companion: CompanionStore, accessibility: AccessibilityPermission) {
        self.nowPlaying = nowPlaying
        self.companion = companion
        self.accessibility = accessibility
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(NotchyStyle.accent.opacity(0.4))
            Form {
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
            .scrollDisabled(true)

            Text("Now Playing con MediaRemoteAdapter © 2025 Jonas van den Berg y colaboradores · BSD-3-Clause")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .frame(width: 440)
        .tint(NotchyStyle.accent)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: MenuBarIcon.image)
                .renderingMode(.template)
                .foregroundStyle(NotchyStyle.accent)
                .scaleEffect(1.6)
                .frame(width: 36, height: 36)
                .background(.black, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(AppInfo.name.uppercased())
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(2)
                Text("v\(AppInfo.version) · ajustes generales")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
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
        case .checking: "comprobando…"
        case .mediaRemote: "MediaRemote"
        case .appleScript(fallback: true): "AppleScript (respaldo)"
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
                if let image = companion.image {
                    CompanionMediaView(image: image, isAnimating: true)
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
                Text(companion.fileURL == nil ? "Destello por defecto" : "Tu imagen")
                    .font(.system(size: 13, weight: .semibold))
                if let error = companion.lastError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                } else {
                    Text("Imagen, GIF o PNG animado de tu Mac")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if companion.fileURL != nil {
                Button("Quitar", action: companion.clear)
            }
            Button("Elegir…", action: companion.chooseFromPanel)
        }
    }
}
