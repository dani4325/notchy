import SwiftUI

struct PanelLevel: View {
    let layout: IslandLayout
    let fraction: Double
    var fill: NSColor?

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        VStack(spacing: layout.textSpacing) {
            LevelBar(fraction: fraction, fill: fill ?? appearance.accentBarColor, track: appearance.barTrackColor, height: layout.progressHeight)
                .frame(height: layout.progressHeight)
                .legibilityMark(.accent)
            Text(verbatim: " ")
                .font(appearance.numericFont(layout.timeSize))
                .hidden()
        }
    }
}
