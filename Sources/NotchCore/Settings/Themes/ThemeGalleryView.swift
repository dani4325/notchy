import SwiftUI

struct ThemeGalleryView: View {
    let editor: ThemeEditorModel

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding(
                get: { editor.draft?.id as String? },
                set: { if let id = $0 { editor.select(themeID: id) } }
            )) {
                ForEach(editor.store.themes) { theme in
                    ThemeCard(
                        theme: theme,
                        appearance: ThemeAppearance.resolve(theme, in: editor.store),
                        isSelected: editor.draft?.id == theme.id,
                        isActive: editor.store.activeThemeID == theme.id,
                        isBuiltIn: editor.store.isBuiltIn(theme.id)
                    )
                    .tag(theme.id as String?)
                    .listRowInsets(EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8))
                    .contextMenu {
                        Button("Usar este tema") {
                            editor.select(themeID: theme.id)
                            editor.activate()
                        }
                        Button("Duplicar") { editor.duplicate(themeID: theme.id) }
                        Button("Exportar…") { editor.exportTheme(themeID: theme.id) }
                        Divider()
                        Button("Mover a la Papelera", role: .destructive) { editor.delete(themeID: theme.id) }
                            .disabled(editor.store.isBuiltIn(theme.id))
                    }
                }
            }
            .listStyle(.plain)
            .onDeleteCommand {
                if let id = editor.draft?.id { editor.delete(themeID: id) }
            }
            if let deleted = editor.undoableDeletion {
                Divider()
                HStack {
                    Text("«\(deleted.name)» está en la Papelera.")
                        .lineLimit(2)
                    Spacer()
                    Button("Deshacer", action: editor.undoDeletion)
                        .keyboardShortcut("z", modifiers: .command)
                }
                .padding(10)
            }
            Divider()
            HStack {
                Button(action: editor.createTheme) {
                    Label("Nuevo", systemImage: "plus")
                }
                Spacer()
                Button(action: editor.importTheme) {
                    Label("Importar…", systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
    }
}

private struct ThemeCard: View {
    let theme: Theme
    let appearance: ThemeAppearance
    let isSelected: Bool
    let isActive: Bool
    let isBuiltIn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [.black, appearance.panel], startPoint: .top, endPoint: .bottom))
                if let background = appearance.background, let settings = theme.background {
                    MediaView(source: background, crop: settings.media.crop, isActive: false)
                        .overlay(appearance.scrimColor.opacity(settings.legibility))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                HStack(spacing: 4) {
                    ForEach([appearance.accent, appearance.secondary, appearance.text], id: \.self) { color in
                        Circle().fill(color).frame(width: 10, height: 10)
                    }
                }
                .padding(8)
            }
            .frame(height: 70)
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(bottomLeadingRadius: 5, bottomTrailingRadius: 5)
                    .fill(.black)
                    .frame(width: 54, height: 9)
            }

            HStack {
                Text(theme.name)
                    .font(.custom(theme.typography.family ?? "", size: 12).weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if isBuiltIn {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                if isActive {
                    Text("EN USO")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NotchyStyle.accent)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? NotchyStyle.accent.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? NotchyStyle.accent : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
