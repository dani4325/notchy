import AppKit

public enum NonNotchMode: String, CaseIterable, Sendable {
    case pill
    case hidden
}

public struct ScreenMetrics: Equatable, Sendable {
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let safeAreaTop: CGFloat
    public let auxiliaryLeftWidth: CGFloat?
    public let auxiliaryRightWidth: CGFloat?

    public init(
        frame: CGRect,
        visibleFrame: CGRect,
        safeAreaTop: CGFloat,
        auxiliaryLeftWidth: CGFloat?,
        auxiliaryRightWidth: CGFloat?
    ) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryLeftWidth = auxiliaryLeftWidth
        self.auxiliaryRightWidth = auxiliaryRightWidth
    }

    @MainActor
    public init(screen: NSScreen) {
        self.init(
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxiliaryRightWidth: screen.auxiliaryTopRightArea?.width
        )
    }
}

public enum NotchLayout: Equatable, Sendable {
    case notch(CGRect)
    case pill(CGRect)
    case none

    public var frame: CGRect? {
        switch self {
        case .notch(let rect), .pill(let rect): rect
        case .none: nil
        }
    }

    public var isNotch: Bool {
        if case .notch = self { true } else { false }
    }
}

public enum NotchGeometry {
    public static let pillWidth: CGFloat = 184
    public static let pillTopInset: CGFloat = 2
    public static let defaultMenuBarHeight: CGFloat = 24

    public static func layout(for screen: ScreenMetrics, nonNotchMode: NonNotchMode) -> NotchLayout {
        if let notch = notchFrame(for: screen) {
            return .notch(notch)
        }
        switch nonNotchMode {
        case .pill: return .pill(pillFrame(for: screen))
        case .hidden: return .none
        }
    }

    static func notchFrame(for screen: ScreenMetrics) -> CGRect? {
        guard screen.safeAreaTop > 0,
              let left = screen.auxiliaryLeftWidth,
              let right = screen.auxiliaryRightWidth
        else { return nil }

        let width = screen.frame.width - left - right
        guard width > 0 else { return nil }

        return CGRect(
            x: screen.frame.minX + left,
            y: screen.frame.maxY - screen.safeAreaTop,
            width: width,
            height: screen.safeAreaTop
        )
    }

    static func pillFrame(for screen: ScreenMetrics) -> CGRect {
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let barHeight = menuBarHeight > 0 ? menuBarHeight : defaultMenuBarHeight
        let height = barHeight - 2 * pillTopInset

        return CGRect(
            x: screen.frame.midX - pillWidth / 2,
            y: screen.frame.maxY - pillTopInset - height,
            width: pillWidth,
            height: height
        )
    }
}

extension NotchGeometry {
    public static func expandedFrame(collapsed: CGRect, size: CGSize, screen: CGRect) -> CGRect {
        let width = min(max(size.width, collapsed.width), screen.width)
        let height = max(size.height, collapsed.height)
        let centeredX = collapsed.midX - width / 2
        let x = min(max(centeredX, screen.minX), screen.maxX - width)

        return CGRect(x: x, y: collapsed.maxY - height, width: width, height: height)
    }
}
