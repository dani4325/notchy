import SwiftUI

struct ThemesSettingsView: View {
    let editor: ThemeEditorModel
    let nowPlaying: NowPlayingStore

    var body: some View {
        NavigationSplitView {
            ThemeGalleryView(editor: editor)
                .navigationSplitViewColumnWidth(min: 210, ideal: 244, max: 320)
        } detail: {
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
        .navigationSplitViewStyle(.balanced)
    }
}
