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
        HStack(spacing: layout.columnGap) {
            Group {
                if shelf.items.isEmpty {
                    dropHint
                } else {
                    ViewThatFits(in: .horizontal) {
                        tileRow
                        ScrollView(.horizontal, showsIndicators: false) { tileRow }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: layout.artworkSide)
            .overlay {
                RoundedRectangle(cornerRadius: layout.artworkCorner, style: .continuous)
                    .strokeBorder(isDropTargeted ? appearance.color(appearance.theme.palette.accent, opacity: 0.9, for: .graphic) : .clear, style: StrokeStyle(lineWidth: max(layout.unit * 0.05, 1), dash: [layout.unit * 0.15]))
            }

            if !shelf.items.isEmpty {
                VStack(spacing: layout.textSpacing * 2) {
                    ShelfActionButton(title: "AirDrop", symbol: "airplayaudio", layout: layout) {
                        Self.airDrop(shelf.items.compactMap(shelf.resolvedURL(for:)))
                    }
                    ShelfActionButton(title: "Vaciar", symbol: "trash", layout: layout, action: shelf.clear)
                }
                .frame(width: layout.controlsWidth * 0.7)
            }
        }
        .padding(.horizontal, layout.padding)
        .frame(width: layout.size.width, height: layout.bodyHeight)
        .onAppear(perform: shelf.refresh)
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

    private var dropHint: some View {
        VStack(spacing: layout.textSpacing * 2) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: layout.artworkSide * 0.3, weight: .medium))
                .foregroundStyle(appearance.accentGraphic)
            Text("Suelta archivos aquí")
                .font(appearance.titleFont(layout.subtitleSize))
                .foregroundStyle(appearance.text)
            Text("Se guardan como accesos, sin copiarlos")
                .font(appearance.bodyFont(layout.timeSize))
                .foregroundStyle(appearance.text.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: layout.artworkCorner, style: .continuous)
                .strokeBorder(appearance.text.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [layout.unit * 0.12]))
        )
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

private struct ShelfActionButton: View {
    let title: LocalizedStringKey
    let symbol: String
    let layout: IslandLayout
    let action: () -> Void

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(appearance.bodyFont(layout.timeSize))
                .frame(maxWidth: .infinity)
                .padding(.vertical, layout.textSpacing * 1.5)
                .background(appearance.accent.opacity(0.16), in: Capsule())
                .foregroundStyle(appearance.text)
        }
        .buttonStyle(.plain)
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
