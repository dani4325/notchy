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
        .buttonStyle(TransportButtonStyle(diameter: layout.controlDiameter, spacing: layout.controlSpacing, tint: appearance.text, pressed: appearance.accentGraphic))
    }

    private var tileRow: some View {
        let resolved: [(item: ShelfItem, url: URL)] = shelf.items.compactMap { item in
            guard let url = shelf.resolvedURL(for: item) else { return nil }
            return (item, url)
        }
        return HStack(spacing: layout.textSpacing * 2) {
            ForEach(resolved, id: \.item.id) { entry in
                ShelfTile(
                    url: entry.url, name: entry.item.name, width: tileWidth, iconSide: iconSide, layout: layout,
                    onAirDrop: { Self.airDrop([entry.url]) },
                    onReveal: { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) },
                    onRemove: { shelf.remove(entry.item.id) }
                )
                    .contextMenu {
                        Button("Compartir por AirDrop") { Self.airDrop([entry.url]) }
                        Button("Mostrar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
                        Divider()
                        Button("Quitar de la estantería") { shelf.remove(entry.item.id) }
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
    let onAirDrop: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

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
                .legibleHalo()
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .legibilityMark(.text)
                .frame(width: width * 0.9, height: layout.timeSize * IslandLayout.lineHeightFactor * 2, alignment: .top)
        }
        .frame(width: width)
        .padding(.vertical, layout.textSpacing)
        .background(appearance.text.opacity(0.06), in: RoundedRectangle(cornerRadius: layout.artworkCorner * 0.6, style: .continuous))
        .contentShape(Rectangle())
        .draggable(url)
        .help(name)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityAction(named: "Mostrar en Finder", onReveal)
        .accessibilityAction(named: "Compartir por AirDrop", onAirDrop)
        .accessibilityAction(named: "Quitar de la estantería", onRemove)
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
            .background(chip, in: Capsule())
            .foregroundStyle(appearance.text.opacity(appearance.background == nil ? 0.85 : 1))
            .frame(minWidth: TransportButtonStyle.minimumTarget, minHeight: TransportButtonStyle.minimumTarget)
            .contentShape(Rectangle())
            .padding(.vertical, (layout.unit * 0.48 - TransportButtonStyle.minimumTarget) / 2)
            }
            .buttonStyle(.plain)
        .accessibilityLabel(page == .shelf ? Text("Volver a la música") : Text("Abrir la estantería"))
    }

    private var chip: Color {
        appearance.background == nil ? appearance.text.opacity(0.1) : appearance.scrimColor.opacity(IconChip.opacity)
    }
}
