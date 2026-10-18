import SwiftUI

public struct SettingsView: View {
    private let nowPlaying: NowPlayingStore
    private let companion: CompanionStore
    private let accessibility: AccessibilityPermission
    private let editor: ThemeEditorModel
    private let router: SettingsRouter

    public init(
        nowPlaying: NowPlayingStore,
        companion: CompanionStore,
        accessibility: AccessibilityPermission,
        editor: ThemeEditorModel,
        router: SettingsRouter
    ) {
        self.router = router
        self.nowPlaying = nowPlaying
        self.companion = companion
        self.accessibility = accessibility
        self.editor = editor
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(NotchyStyle.accent.opacity(0.4))
            switch router.section {
            case .themes:
                ThemesSettingsView(editor: editor, nowPlaying: nowPlaying)
            case .general:
                GeneralSettingsView(nowPlaying: nowPlaying, companion: companion, accessibility: accessibility)
            }
        }
        .frame(width: 900, height: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(NotchyStyle.accent)
        .onDisappear { editor.flush() }
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
                Text("v\(AppInfo.version) · ajustes")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Sección", selection: Bindable(router).section) {
                ForEach(SettingsSection.allCases, id: \.self) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
        }
        .padding(16)
    }
}
