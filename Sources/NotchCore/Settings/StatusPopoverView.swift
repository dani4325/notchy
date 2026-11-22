import AppKit
import SwiftUI

public struct StatusPopoverView: View {
    private let themes: ThemeStore
    private let router: SettingsRouter
    private let updater: SoftwareUpdating?

    @AppStorage(Preferences.Key.wingsMode) private var wingsMode = WingsMode.withMusic.rawValue
    @AppStorage(Preferences.Key.shelf) private var shelfEnabled = true
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    public init(themes: ThemeStore, router: SettingsRouter, updater: SoftwareUpdating? = nil) {
        self.themes = themes
        self.router = router
        self.updater = updater
    }

    public var body: some View {
        let theme = themes.activeTheme
        let appearance = ThemeAppearance.resolve(theme, in: themes)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AppInfo.name)
                    .font(.headline)
                Spacer()
                Text("Activo")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            Button(action: openThemes) {
                HStack(spacing: 10) {
                    ActiveThemeThumbnail(theme: theme, appearance: appearance)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tema activo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(theme.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(8)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(PopoverCardButtonStyle())
            .accessibilityLabel(Text("Tema activo"))
            .accessibilityValue(theme.name)

            Divider()

            VStack(spacing: 8) {
                Toggle("Alas junto al notch", isOn: Binding(
                    get: { wingsMode != WingsMode.never.rawValue },
                    set: { wingsMode = $0 ? WingsMode.withMusic.rawValue : WingsMode.never.rawValue }
                ))
                Toggle("Estantería de archivos", isOn: $shelfEnabled)
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Divider()

            VStack(spacing: 2) {
                PopoverActionRow(title: "Temas y ajustes…", systemImage: "paintpalette", shortcut: .settings, action: openThemes)
                    .keyboardShortcut(",")

                if let updater {
                    PopoverActionRow(
                        title: "Buscar actualizaciones…",
                        systemImage: "arrow.triangle.2.circlepath",
                        action: {
                            dismiss()
                            updater.checkForUpdates()
                        }
                    )
                    .disabled(!updater.canCheckForUpdates)
                }

                Divider()
                    .padding(.vertical, 4)

                PopoverActionRow(
                    title: "Salir de \(AppInfo.name)",
                    shortcut: .quit,
                    action: { NSApp.terminate(nil) }
                )
                .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 264)
        .tint(NotchyStyle.accent)
    }

    private func openThemes() {
        router.section = .themes
        dismiss()
        openSettings()
        NSApp.activate()
    }
}

private struct ActiveThemeThumbnail: View {
    let theme: Theme
    let appearance: ThemeAppearance

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(appearance.panel)
            if let background = appearance.background, let settings = theme.background {
                MediaView(source: background, crop: settings.media.crop, isActive: false)
                    .overlay(appearance.scrimColor.opacity(settings.legibility))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            HStack(spacing: 3) {
                ForEach(PaletteSwatchRole.allCases, id: \.self) { role in
                    Circle().fill(appearance.color(for: role)).frame(width: 6, height: 6)
                }
            }
            .padding(5)
        }
        .frame(width: 48, height: 32)
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: 2.5, bottomTrailingRadius: 2.5)
                .fill(.black)
                .frame(width: 16, height: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 0.75)
        )
        .accessibilityHidden(true)
    }
}

private enum PopoverShortcutHint {
    case settings
    case quit

    var key: Character {
        switch self {
        case .settings: ","
        case .quit: "Q"
        }
    }
}

private struct PopoverActionRow: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var shortcut: PopoverShortcutHint?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .frame(width: 16, alignment: .center)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                Spacer(minLength: 8)
                if let shortcut {
                    HStack(spacing: 1) {
                        Image(systemName: "command")
                        Text(verbatim: String(shortcut.key))
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(PopoverRowButtonStyle())
    }
}

private struct PopoverCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct PopoverRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? AnyShapeStyle(.primary.opacity(0.1)) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
    }
}
