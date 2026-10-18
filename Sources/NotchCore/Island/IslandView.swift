import SwiftUI

struct IslandView: View {
    let isNotch: Bool

    @AppStorage(Preferences.Key.showCalibrationOutline) private var showOutline = false

    private static let notchBottomRadius: CGFloat = 10
    private static let calibrationColor = Color(red: 1, green: 0.42, blue: 0.1)

    var body: some View {
        shape
            .fill(.black)
            .overlay {
                if showOutline {
                    shape.stroke(Self.calibrationColor, lineWidth: 1)
                }
            }
    }

    private var shape: AnyShape {
        isNotch
            ? AnyShape(NotchShape(bottomRadius: Self.notchBottomRadius))
            : AnyShape(Capsule(style: .continuous))
    }
}
