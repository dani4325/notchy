import AppKit
import SwiftUI

struct ShelfView: View {
    let layout: IslandLayout
    let shelf: ShelfStore
    let isDropTargeted: Bool

    @Environment(\.themeAppearance) private var appearance

    private var tileWidth: CGFloat { layout.artworkSide * 0.82 }
    private var iconSide: CGFloat { layout.artworkSide * 0.52 }

    var body: some View {
        Group {
            if shelf.items.isEmpty {
                PanelRow(
                    layout: layout,
                    subtitle: Text("Para tenerlos a mano desde el notch."),
                    subtitleLines: 2,
                    showsBar: false
                ) {
                    PanelSymbol(layout: layout, systemName: "tray.and.arrow.down")
                } title: {
                    Text("Suelta archivos aquí")
                } accessory: {
                    EmptyView()
                } bar: {
                    EmptyView()
                } trailing: {
                    Color.clear
                }
            } else {
                HStack(spacing: layout.columnGap) {
                    ViewThatFits(in: .horizontal) {
                        tileRow
                        ScrollView(.horizontal, showsIndicators: false) { tileRow }
                    }
                    .frame(width: layout.artworkSide + layout.columnGap + max(layout.textWidth, 0), height: layout.artworkSide, alignment: .leading)
                    actions
                        .frame(width: layout.controlsWidth)
                }
                .padding(.leading, layout.padding)
                .padding(.trailing, layout.trailingPadding)
                .frame(width: layout.size.width, height: layout.bodyHeight)
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: layout.artworkCorner, style: .continuous)
                    .strokeBorder(appearance.accentGraphic, style: StrokeStyle(lineWidth: max(layout.unit * 0.05, 1), dash: [layout.unit * 0.15]))
                    .padding(layout.padding * 0.5)
            }
        }
        .onAppear(perform: shelf.refresh)
    }

    private var actions: some View {
        HStack(spacing: layout.controlSpacing) {
            Button {
                Self.airDrop(shelf.items.compactMap(shelf.resolvedURL(for:)))
            } label: {
                Image(systemName: "square.and.arrow.up").font(.system(size: layout.skipIconSize))
            }
            .accessibilityLabel("Compartir por AirDrop")
            .help("Compartir por AirDrop")
            Button(action: shelf.clear) {
                Image(systemName: "trash").font(.system(size: layout.skipIconSize))
            }
            .accessibilityLabel("Vaciar la estantería")
            .help("Vaciar la estantería")
        }
        .buttonStyle(TransportButtonStyle(diameter: layout.controlDiameter, tint: appearance.text, pressed: appearance.accentGraphic))
    }

    private var tileRow: some View {
        HStack(spacing: layout.textSpacing * 2) {
            ForEach(shelf.items) { item in
                if let url = shelf.resolvedURL(for: item) {
                    ShelfTile(url: url, name: item.name, width: tileWidth, iconSide: iconSide, layout: layout)
                        .contextMenu {
                            Button("Compartir por AirDrop") { Self.airDrop([url]) }
                            Button("Mostrar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                            Divider()
                            Button("Quitar de la estantería") { shelf.remove(item.id) }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func airDrop(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
    }
}

private struct ShelfTile: View {
    let url: URL
    let name: String
    let width: CGFloat
    let iconSide: CGFloat
    let layout: IslandLayout

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        VStack(spacing: layout.textSpacing) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: iconSide, height: iconSide)
            Text(name)
                .font(appearance.bodyFont(layout.timeSize))
                .foregroundStyle(appearance.text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .frame(width: width * 0.9, height: layout.timeSize * IslandLayout.lineHeightFactor * 2, alignment: .top)
        }
        .frame(width: width)
        .padding(.vertical, layout.textSpacing)
        .background(appearance.text.opacity(0.06), in: RoundedRectangle(cornerRadius: layout.artworkCorner * 0.6, style: .continuous))
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .help(name)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }
}

struct PageToggleButton: View {
    let page: IslandPage
    let count: Int
    let layout: IslandLayout
    let action: () -> Void

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        Button(action: action) {
            HStack(spacing: layout.unit * 0.08) {
                Image(systemName: page == .shelf ? "music.note" : "tray.full")
                if page == .main, count > 0 {
                    Text("\(count)").monospacedDigit()
                }
            }
            .font(.system(size: layout.labelSize * 1.1, weight: .semibold))
            .padding(.horizontal, layout.unit * 0.18)
            .frame(height: layout.unit * 0.48)
            .background(appearance.text.opacity(0.1), in: Capsule())
            .foregroundStyle(appearance.text.opacity(0.85))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(page == .shelf ? Text("Volver a la música") : Text("Abrir la estantería"))
    }
}
