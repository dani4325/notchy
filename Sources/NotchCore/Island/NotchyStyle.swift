import AppKit
import SwiftUI

enum NotchyStyle {
    static let brand = Color(Theme.notchyDefault.palette.accent)

    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let hex = isDark ? Theme.notchyDefault.palette.accent : lightModeAccent
        return NSColor(srgbRed: hex.red, green: hex.green, blue: hex.blue, alpha: 1)
    })

    private static let lightModeAccent = HexColor("#A63F0A")!
}
