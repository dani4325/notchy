import SwiftUI

struct ThemesSettingsView: View {
    let editor: ThemeEditorModel
    let nowPlaying: NowPlayingStore

    var body: some View {
        HStack(spacing: 0) {
            ThemeGalleryView(editor: editor)
                .frame(width: 236)
            Divider()
            if let draft = editor.draft {
                VStack(spacing: 0) {
                    ThemePreviewView(editor: editor, theme: draft, nowPlaying: nowPlaying)
                    Divider()
                    ThemeEditorView(editor: editor, theme: draft)
                }
            } else {
                ContentUnavailableView("Elige un tema", systemImage: "paintpalette")
            }
        }
    }
}
