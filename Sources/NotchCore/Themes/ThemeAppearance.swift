import AppKit
import SwiftUI

public struct ThemeAppearance: Sendable {
    public let theme: Theme
    public let background: MediaSource?

    public init(theme: Theme, background: MediaSource?) {
        self.theme = theme
        self.background = background
    }

    var accent: Color { Color(theme.palette.accent) }
    var secondary: Color { Color(theme.palette.secondary) }
    var panel: Color { Color(theme.palette.panel) }
    var text: Color { Color(theme.palette.text) }

    var hasLightText: Bool { theme.palette.text.rgb.brightness > 0.5 }

    var scrimColor: Color {
        guard hasLightText else { return .white }
        return theme.palette.panel.rgb.brightness < 0.2 ? panel : .black
    }

    var textShadow: Color {
        background == nil ? .clear : scrimColor.opacity(0.55)
    }

    func titleFont(_ size: CGFloat) -> Font {
        font(size: size, weight: theme.typography.titleWeight.fontWeight)
    }

    func bodyFont(_ size: CGFloat) -> Font {
        font(size: size, weight: .medium)
    }

    func labelFont(_ size: CGFloat) -> Font {
        font(size: size, weight: .heavy)
    }

    func numericFont(_ size: CGFloat) -> Font {
        font(size: size, weight: .medium).monospacedDigit()
    }

    private func font(size: CGFloat, weight: Font.Weight) -> Font {
        if let family = theme.typography.family, NSFontManager.shared.availableMembers(ofFontFamily: family) != nil {
            return Font.custom(family, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: theme.typography.design.fontDesign)
    }

    @MainActor
    public static func resolve(_ theme: Theme, in store: ThemeStore) -> ThemeAppearance {
        let background = theme.background.map {
            MediaSource(url: store.mediaURL(themeID: theme.id, media: $0.media), kind: $0.media.kind)
        }
        return ThemeAppearance(theme: theme, background: background)
    }
}

extension Color {
    init(_ hex: HexColor) {
        self.init(.sRGB, red: hex.red, green: hex.green, blue: hex.blue, opacity: hex.alpha)
    }
}

extension FontDesign {
    var fontDesign: Font.Design {
        switch self {
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }
}

extension FontWeightName {
    var fontWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

private struct ThemeAppearanceKey: EnvironmentKey {
    static let defaultValue = ThemeAppearance(theme: .notchyDefault, background: nil)
}

extension EnvironmentValues {
    var themeAppearance: ThemeAppearance {
        get { self[ThemeAppearanceKey.self] }
        set { self[ThemeAppearanceKey.self] = newValue }
    }
}
