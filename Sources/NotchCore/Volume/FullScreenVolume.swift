import AppKit
import CoreGraphics

enum InterceptionSafeguard {
    static func interceptionFailed(before: VolumeReading, after: VolumeReading, key: MediaKeyKind) -> Bool {
        guard before.level == after.level, before.isMuted == after.isMuted else { return false }
        switch key {
        case .volumeUp: return !before.isMuted && before.level < 1
        case .volumeDown: return !before.isMuted && before.level > 0
        case .mute: return true
        }
    }
}

enum FullScreenState: Equatable {
    case none
    case besideNotch
    case coversNotch
}

struct ScreenWindow: Equatable {
    let ownerPID: pid_t
    let layer: Int
    let name: String
    let frame: CGRect
}

enum FullScreenClassifier {
    static let menuBarWindowKey = "Menubar"
    private static let tolerance: CGFloat = 1

    static func classify(windows: [ScreenWindow], frontmostPID: pid_t, screen: CGRect, notchHeight: CGFloat) -> FullScreenState {
        let fills = windows.filter { window in
            window.ownerPID == frontmostPID && window.layer == 0
                && window.frame.width >= screen.width - tolerance
                && window.frame.maxY >= screen.maxY - tolerance
                && window.frame.minY <= screen.minY + notchHeight + tolerance
        }
        guard !fills.isEmpty else { return .none }
        if fills.contains(where: { $0.frame.minY <= screen.minY + tolerance }) { return .coversNotch }
        let menuBarVisible = windows.contains { window in
            window.name == menuBarWindowKey && window.frame.minY <= screen.minY + tolerance && window.frame.intersects(screen)
        }
        return menuBarVisible ? .none : .besideNotch
    }
}

@MainActor
enum FullScreenDetector {
    static func current() -> FullScreenState {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }),
              let displayID = screen.displayID,
              let frontmost = NSWorkspace.shared.frontmostApplication,
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return .none }
        let windows = info.compactMap { entry -> ScreenWindow? in
            guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { return nil }
            return ScreenWindow(
                ownerPID: pid,
                layer: entry[kCGWindowLayer as String] as? Int ?? 0,
                name: entry[kCGWindowName as String] as? String ?? "",
                frame: frame
            )
        }
        return FullScreenClassifier.classify(
            windows: windows, frontmostPID: frontmost.processIdentifier,
            screen: CGDisplayBounds(displayID), notchHeight: screen.safeAreaInsets.top
        )
    }
}
