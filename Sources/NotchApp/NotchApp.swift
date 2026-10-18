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
            SettingsView(nowPlaying: appDelegate.nowPlaying, companion: appDelegate.companion)
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
    private lazy var wings = WingsVisibility(nowPlaying: nowPlaying)
    private lazy var notchController = NotchWindowController(nowPlaying: nowPlaying, companion: companion, wings: wings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        nowPlaying.start()
        wings.start()
        notchController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchController.stop()
        wings.stop()
        nowPlaying.stop()
    }
}
