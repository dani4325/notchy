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
            SettingsView()
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
    private let notchController = NotchWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchController.stop()
    }
}
