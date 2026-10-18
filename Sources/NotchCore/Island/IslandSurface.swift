import SwiftUI

struct IslandSurface: View {
    let model: IslandModel
    let appearance: ThemeAppearance
    let showOutline: Bool

    var body: some View {
        let shape = model.shape
        let size = model.currentSize
        let stem = model.stemHeight

        ZStack(alignment: .top) {
            Color.black
            if model.isExpanded {
                IslandBody(appearance: appearance, layout: model.layout)
                    .frame(width: size.width, height: max(size.height - stem, 0))
                    .padding(.top, stem)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .overlay {
            if model.isExpanded, appearance.theme.effects.borderWidth > 0 {
                shape.stroke(appearance.accent.opacity(0.7), lineWidth: appearance.theme.effects.borderWidth)
            }
        }
        .overlay {
            if showOutline {
                shape.stroke(NotchyStyle.accent, lineWidth: 1)
            }
        }
    }
}

struct IslandBody: View {
    let appearance: ThemeAppearance
    let layout: IslandLayout

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if let source = appearance.background, let settings = appearance.theme.background {
                    BackgroundMediaView(source: source, crop: settings.media.crop, size: proxy.size)
                    LegibilityScrim(appearance: appearance, layout: layout, strength: settings.legibility)
                } else {
                    LinearGradient(colors: [.black, appearance.panel], startPoint: .top, endPoint: .bottom)
                }
                EllipticalGradient(
                    colors: [.black, .black.opacity(0.6), .black.opacity(0)],
                    center: .top,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.5
                )
                .frame(width: layout.topBlendWidth, height: min(2 * layout.topBlendHeight, proxy.size.height))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }
}

struct LegibilityScrim: View {
    let appearance: ThemeAppearance
    let layout: IslandLayout
    let strength: Double

    static let artworkShare = 0.75
    static let controlsShare = 0.85

    var body: some View {
        let width = max(layout.size.width, 1)
        let textStart = (layout.padding + layout.artworkSide + layout.columnGap) / width
        let textEnd = textStart + layout.textWidth / width
        let color = appearance.scrimColor

        LinearGradient(
            stops: [
                .init(color: color.opacity(strength * Self.artworkShare), location: 0),
                .init(color: color.opacity(strength), location: textStart),
                .init(color: color.opacity(strength), location: textEnd),
                .init(color: color.opacity(strength * Self.controlsShare), location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct BackgroundMediaView: View {
    let source: MediaSource
    let crop: MediaCrop
    let size: CGSize

    var body: some View {
        if source.kind == .image, let image = MediaImageCache.image(at: source.url) {
            CroppedImageView(image: image, crop: crop, size: size)
        } else {
            MediaView(source: source, crop: crop, isActive: true)
                .frame(width: size.width, height: size.height)
        }
    }
}

struct CroppedImageView: View {
    let image: NSImage
    let crop: MediaCrop
    let size: CGSize

    var body: some View {
        let aspect = image.size.height > 0 ? image.size.width / image.size.height : 1
        let window = crop.rect(mediaAspect: aspect, targetAspect: size.height > 0 ? size.width / size.height : 1)
        let content = CGSize(width: size.width / window.width, height: size.height / window.height)

        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: content.width, height: content.height)
            .offset(x: -window.minX * content.width, y: -window.minY * content.height)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
    }
}

@MainActor
enum MediaImageCache {
    private static let cache = NSCache<NSURL, NSImage>()

    static func image(at url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
