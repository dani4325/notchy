import SwiftUI

struct PanelRow<Tile: View, Title: View, Accessory: View, Bar: View, Trailing: View>: View {
    let layout: IslandLayout
    var subtitle: Text?
    var subtitleLines = 1
    var showsBar = true
    var tileNeedsVeil = true
    @ViewBuilder let tile: () -> Tile
    @ViewBuilder let title: () -> Title
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let bar: () -> Bar
    @ViewBuilder let trailing: () -> Trailing

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        HStack(spacing: layout.columnGap) {
            tile()
                .frame(width: layout.artworkSide, height: layout.artworkSide)
                .legibilityMarkIfNeeded(tileNeedsVeil ? .graphics : [])
            VStack(alignment: .leading, spacing: layout.textSpacing) {
                if !showsBar { Spacer(minLength: 0) }
                HStack(alignment: .firstTextBaseline, spacing: layout.textSpacing) {
                    title()
                        .font(appearance.titleFont(layout.titleSize))
                        .foregroundStyle(appearance.text)
                        .legibilityMark(.text, letterHeight: layout.titleSize)
                    Spacer(minLength: 0)
                    accessory()
                        .legibilityMark(.accent)
                }
                if let subtitle {
                    subtitle
                        .font(appearance.bodyFont(layout.subtitleSize))
                        .foregroundStyle(appearance.secondaryTextColor)
                        .lineLimit(subtitleLines)
                        .legibilityMark(.text, letterHeight: subtitleLines == 1 ? layout.subtitleSize : nil)
                }
                Spacer(minLength: showsBar ? layout.progressGap : 0)
                if showsBar { bar() }
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: max(layout.textWidth, 0), height: layout.artworkSide, alignment: .leading)
            trailing()
                .frame(width: layout.controlsWidth)
        }
        .padding(.leading, layout.padding)
        .padding(.trailing, layout.trailingPadding)
        .frame(width: layout.size.width, height: layout.bodyHeight)
    }
}

struct PanelTile<Content: View>: View {
    let layout: IslandLayout
    @ViewBuilder let content: () -> Content

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        RoundedRectangle(cornerRadius: layout.artworkCorner, style: .continuous)
            .fill(appearance.text.opacity(PanelTile<EmptyView>.fillOpacity))
            .overlay { content() }
            .frame(width: layout.artworkSide, height: layout.artworkSide)
    }

    static var fillOpacity: Double { 0.08 }
}

struct PanelSymbol: View {
    let layout: IslandLayout
    let systemName: String

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        PanelTile(layout: layout) {
            Image(systemName: systemName)
                .font(.system(size: layout.artworkSide * 0.34, weight: .semibold))
                .foregroundStyle(appearance.text)
                .contentTransition(.symbolEffect(.replace))
        }
    }
}
