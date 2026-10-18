import NotchCore
import SwiftUI

@main
struct NotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            StatusMenu()
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }

        Window(AppInfo.name, id: StatusMenu.settingsWindowID) {
            SettingsView(
                nowPlaying: appDelegate.nowPlaying,
                companion: appDelegate.companion,
                accessibility: appDelegate.accessibility,
                editor: appDelegate.themeEditor,
                router: appDelegate.settingsRouter,
                loginItem: appDelegate.loginItem,
                autoThemes: appDelegate.autoThemes,
                shelf: appDelegate.shelf,
                onboarding: appDelegate.onboarding
            )
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

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
    static let settingsWindowID = "settings"

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Ajustes…") {
            openWindow(id: Self.settingsWindowID)
            NSApp.activate()
        }
        .keyboardShortcut(",")
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
    private let power = PowerMonitor()
    private let volumeHUD = VolumeHUDCoordinator()
    lazy var autoThemes = AutoThemeController(store: themes)
    private lazy var wings = WingsVisibility(nowPlaying: nowPlaying)
    private lazy var notchController = NotchWindowController(
        nowPlaying: nowPlaying, companion: companion, wings: wings, themes: themes, shelf: shelf
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        volumeHUD.onShow = { [weak self] reading in self?.notchController.show(reading) }
        volumeHUD.start()
        onboarding.onTryPanel = { [weak self] in self?.notchController.greet() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.pathExtension.lowercased() == "notchytheme" {
            themeEditor.importTheme(from: url)
            themeEditor.activate()
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
