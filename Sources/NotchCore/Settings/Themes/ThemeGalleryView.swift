import SwiftUI

struct ThemeGalleryView: View {
    let editor: ThemeEditorModel

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding(
                get: { editor.draft?.id as String? },
                set: { if let id = $0 { editor.select(themeID: id) } }
            )) {
                ForEach(editor.filteredThemes) { theme in
                    ThemeCard(
                        theme: theme,
                        appearance: ThemeAppearance.resolve(theme, in: editor.store),
                        isActive: editor.store.activeThemeID == theme.id,
                        isBuiltIn: editor.store.isBuiltIn(theme.id)
                    )
                    .tag(theme.id as String?)
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
            .listStyle(.sidebar)
            .searchable(text: Bindable(editor).searchQuery, placement: .sidebar, prompt: Text("Buscar temas"))
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
            HStack(spacing: 12) {
                Button(action: editor.createTheme) {
                    Label("Nuevo", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                Button {
                    if let id = editor.draft?.id { editor.duplicate(themeID: id) }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel("Duplicar")
                .help("Duplicar")
                .disabled(editor.draft == nil)
                .keyboardShortcut("d", modifiers: .command)
                Spacer()
                Button(action: editor.importTheme) {
                    Label("Importar…", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("i", modifiers: .command)
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
    }
}

private struct ThemeCard: View {
    let theme: Theme
    let appearance: ThemeAppearance
    let isActive: Bool
    let isBuiltIn: Bool

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(theme.name)
                    .font(appearance.titleFont(Self.nameSize))
                    .lineLimit(1)
                if isActive {
                    Label("En uso", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isBuiltIn {
                    Label("Incluido", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private static let nameSize: CGFloat = 13
    private static let thumbnailSize = CGSize(width: 72, height: 40)

    private var thumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(appearance.panel)
            if let background = appearance.background, let settings = theme.background {
                MediaView(source: background, crop: settings.media.crop, isActive: false)
                    .overlay(appearance.scrimColor.opacity(settings.legibility))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            HStack(spacing: 3) {
                ForEach(PaletteSwatchRole.allCases, id: \.self) { role in
                    Circle().fill(appearance.color(for: role)).frame(width: 7, height: 7)
                }
            }
            .padding(5)
        }
        .frame(width: Self.thumbnailSize.width, height: Self.thumbnailSize.height)
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3)
                .fill(.black)
                .frame(width: 26, height: 5)
        }
        .accessibilityHidden(true)
    }
}
