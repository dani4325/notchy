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

struct ScreenWindow: Equatable {
    let ownerPID: pid_t
    let layer: Int
    let name: String
    let frame: CGRect
}

enum FullScreenClassifier {
    static let menuBarWindowKey = "Menubar"
    static let menuBarLayer = Int(CGWindowLevelForKey(.mainMenuWindow))
    private static let tolerance: CGFloat = 1
    private static let maxMenuBarHeight: CGFloat = 44

    static func isFullScreen(windows: [ScreenWindow], frontmostPID: pid_t, screen: CGRect, notchHeight: CGFloat) -> Bool {
        let fills = windows.filter { window in
            window.ownerPID == frontmostPID && window.layer == 0
                && window.frame.width >= screen.width - tolerance
                && window.frame.maxY >= screen.maxY - tolerance
                && window.frame.minY <= screen.minY + notchHeight + tolerance
        }
        guard !fills.isEmpty else { return false }
        if fills.contains(where: { $0.frame.minY <= screen.minY + tolerance }) { return true }
        let menuBarCeiling = max(notchHeight, maxMenuBarHeight) + tolerance
        let menuBarVisible = windows.contains { window in
            let isMenuBar = window.name == menuBarWindowKey
                || (window.layer == menuBarLayer
                    && window.frame.width >= screen.width - tolerance
                    && window.frame.height > 0
                    && window.frame.height <= menuBarCeiling)
            return isMenuBar && window.frame.minY <= screen.minY + tolerance && window.frame.intersects(screen)
        }
        return !menuBarVisible
    }
}

@MainActor
enum FullScreenDetector {
    static func isActive() -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return false }
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
        let frontmostPID = frontmost.processIdentifier
        return NSScreen.screens.contains { screen in
            guard let displayID = screen.displayID else { return false }
            let topInset = screen.safeAreaInsets.top > 0
                ? screen.safeAreaInsets.top
                : max(screen.frame.maxY - screen.visibleFrame.maxY, 0)
            return FullScreenClassifier.isFullScreen(
                windows: windows, frontmostPID: frontmostPID,
                screen: CGDisplayBounds(displayID), notchHeight: topInset
            )
        }
    }
}
