import SwiftUI

public struct SettingsView: View {
    private let nowPlaying: NowPlayingStore
    private let companion: CompanionStore
    private let accessibility: AccessibilityPermission
    private let editor: ThemeEditorModel
    private let router: SettingsRouter
    private let loginItem: LoginItem
    private let autoThemes: AutoThemeController
    private let shelf: ShelfStore
    private let onboarding: OnboardingModel
    private let updater: SoftwareUpdating?

    @Environment(\.openWindow) private var openWindow

    public init(
        nowPlaying: NowPlayingStore,
        companion: CompanionStore,
        accessibility: AccessibilityPermission,
        editor: ThemeEditorModel,
        router: SettingsRouter,
        loginItem: LoginItem,
        autoThemes: AutoThemeController,
        shelf: ShelfStore,
        onboarding: OnboardingModel,
        updater: SoftwareUpdating? = nil
    ) {
        self.updater = updater
        self.shelf = shelf
        self.onboarding = onboarding
        self.autoThemes = autoThemes
        self.router = router
        self.loginItem = loginItem
        self.nowPlaying = nowPlaying
        self.companion = companion
        self.accessibility = accessibility
        self.editor = editor
    }

    public var body: some View {
        TabView(selection: Bindable(router).section) {
            Tab(SettingsSection.themes.title, systemImage: "paintpalette", value: SettingsSection.themes) {
                ThemesSettingsView(editor: editor, nowPlaying: nowPlaying)
                    .frame(
                        minWidth: Self.themesMinSize.width,
                        idealWidth: Self.themesIdealSize.width,
                        minHeight: Self.themesMinSize.height,
                        idealHeight: Self.themesIdealSize.height
                    )
            }
            Tab(SettingsSection.general.title, systemImage: "gearshape", value: SettingsSection.general) {
                GeneralSettingsView(
                    nowPlaying: nowPlaying, companion: companion, accessibility: accessibility,
                    loginItem: loginItem, autoThemes: autoThemes, themes: editor.store, shelf: shelf,
                    updater: updater, showWelcome: showWelcome
                )
                .frame(
                    minWidth: Self.generalMinSize.width,
                    idealWidth: Self.generalIdealSize.width,
                    minHeight: Self.generalMinSize.height,
                    idealHeight: Self.generalIdealSize.height
                )
                .onAppear(perform: loginItem.refresh)
            }
        }
        .tint(NotchyStyle.accent)
        .onDisappear { editor.flush() }
    }

    private static let themesMinSize = CGSize(width: 760, height: 540)
    private static let themesIdealSize = CGSize(width: 920, height: 640)
    private static let generalMinSize = CGSize(width: 520, height: 540)
    private static let generalIdealSize = CGSize(width: 560, height: 640)

    private func showWelcome() {
        onboarding.restart()
        openWindow(id: OnboardingModel.windowID)
    }
}

extension View {
    func settingsFooter() -> some View {
        foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
