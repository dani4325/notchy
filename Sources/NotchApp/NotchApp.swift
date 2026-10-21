import NotchCore
import SwiftUI

@main
struct NotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            StatusMenu(updater: appDelegate.updater)
        } label: {
            Image(nsImage: MenuBarIcon.image)
                .accessibilityLabel(AppInfo.name)
        }

        Settings {
            SettingsView(
                nowPlaying: appDelegate.nowPlaying,
                companion: appDelegate.companion,
                accessibility: appDelegate.accessibility,
                editor: appDelegate.themeEditor,
                router: appDelegate.settingsRouter,
                loginItem: appDelegate.loginItem,
                autoThemes: appDelegate.autoThemes,
                shelf: appDelegate.shelf,
                onboarding: appDelegate.onboarding,
                updater: appDelegate.updater
            )
        }

        Window(AppInfo.name, id: OnboardingModel.windowID) {
            OnboardingView(
                model: appDelegate.onboarding,
                accessibility: appDelegate.accessibility,
                loginItem: appDelegate.loginItem,
                themes: appDelegate.themes
            )
            .onAppear { NSApp.activate() }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(OnboardingModel.needsOnboarding() ? .presented : .suppressed)
    }
}

struct StatusMenu: View {
    let updater: SparkleUpdater

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Ajustes…") {
            openSettings()
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Button("Buscar actualizaciones…", action: updater.checkForUpdates)
            .disabled(!updater.canCheckForUpdates)
        Divider()
        Button("Salir de \(AppInfo.name)") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let nowPlaying = NowPlayingStore()
    let companion = CompanionStore()
    let accessibility = AccessibilityPermission()
    let themes = ThemeStore()
    let shelf = ShelfStore(limit: Preferences.shelfLimit)
    lazy var themeEditor = ThemeEditorModel(store: themes)
    let settingsRouter = SettingsRouter()
    let loginItem = LoginItem()
    let onboarding = OnboardingModel()
    let updater = SparkleUpdater()
    private let power = PowerMonitor()
    private let volumeHUD = VolumeHUDCoordinator()
    lazy var autoThemes = AutoThemeController(store: themes)
    private lazy var wings = WingsVisibility(nowPlaying: nowPlaying)
    private lazy var notchController = NotchWindowController(
        nowPlaying: nowPlaying, companion: companion, wings: wings, themes: themes, shelf: shelf
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await themes.migrateGIFBackgrounds()
            await themes.measureMissing()
            await companion.migrateGIF()
        }
        if let fonts = FontRegistry.bundledFontsDirectory {
            FontRegistry.register(directory: fonts)
        }
        nowPlaying.start()
        accessibility.start()
        wings.start()
        notchController.start()
        power.onEvent = { [weak self] event in self?.notchController.show(event) }
        power.start()
        autoThemes.start()
        volumeHUD.onShow = { [weak self] reading, direction, limit in self?.notchController.show(reading, direction: direction, limit: limit) }
        notchController.onVolumeStep = { [weak self] kind in self?.volumeHUD.step(kind) }
        volumeHUD.start()
        onboarding.onTryPanel = { [weak self] in self?.notchController.greet() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let themes = urls.filter { $0.pathExtension.lowercased() == "notchytheme" }
        Task {
            for url in themes where await themeEditor.importTheme(from: url) {
                themeEditor.activate()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        themeEditor.flush()
        power.stop()
        autoThemes.stop()
        volumeHUD.stop()
        notchController.stop()
        wings.stop()
        accessibility.stop()
        nowPlaying.stop()
    }
}
