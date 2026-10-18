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
                loginItem: appDelegate.loginItem
            )
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
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
    lazy var themeEditor = ThemeEditorModel(store: themes)
    let settingsRouter = SettingsRouter()
    let loginItem = LoginItem()
    private lazy var wings = WingsVisibility(nowPlaying: nowPlaying)
    private lazy var notchController = NotchWindowController(
        nowPlaying: nowPlaying, companion: companion, wings: wings, themes: themes
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let fonts = FontRegistry.bundledFontsDirectory {
            FontRegistry.register(directory: fonts)
        }
        nowPlaying.start()
        accessibility.start()
        wings.start()
        notchController.start()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.pathExtension.lowercased() == "notchytheme" {
            themeEditor.importTheme(from: url)
            themeEditor.activate()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        themeEditor.flush()
        notchController.stop()
        wings.stop()
        accessibility.stop()
        nowPlaying.stop()
    }
}
