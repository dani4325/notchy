import ImageIO
import SwiftUI

struct IslandSurface: View {
    let model: IslandModel
    let appearance: ThemeAppearance
    let showOutline: Bool

    var body: some View {
        let shape = model.shape
        let size = model.currentSize
        let stem = model.stemHeight
        let bodySize = CGSize(width: size.width, height: max(size.height - stem, 0))

        ZStack(alignment: .top) {
            Color.black
            if model.isExpanded {
                IslandBody(
                    appearance: appearance,
                    layout: model.layout,
                    size: bodySize,
                    marks: model.legibilityMarks.map { LegibilityMark(needs: $0.needs, rect: $0.rect.offsetBy(dx: 0, dy: -stem)) }
                )
                    .frame(width: bodySize.width, height: bodySize.height)
                    .padding(.top, stem)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .overlay {
            if model.isExpanded, appearance.theme.effects.borderWidth > 0 {
                shape.stroke(appearance.color(appearance.theme.palette.accent, opacity: 0.7, for: .graphic), lineWidth: appearance.theme.effects.borderWidth)
            }
        }
        .overlay {
            if showOutline {
                shape.stroke(NotchyStyle.brand, lineWidth: 1)
            }
        }
    }
}

struct IslandBody: View {
    let appearance: ThemeAppearance
    let layout: IslandLayout
    let size: CGSize
    var marks: [LegibilityMark] = []

    var body: some View {
        ZStack(alignment: .top) {
            if let source = appearance.background, let settings = appearance.theme.background {
                BackgroundMediaView(source: source, crop: settings.media.crop, size: size)
                LegibilityScrim(
                    appearance: appearance, layout: layout, crop: settings.media.crop,
                    minimum: settings.legibility, size: size, marks: marks
                )
            } else {
                LinearGradient(colors: [.black, appearance.panel], startPoint: .top, endPoint: .bottom)
            }
            if let decoration = appearance.theme.decoration {
                ThemeDecorationView(decoration: decoration, layout: layout, appearance: appearance)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            }
            EllipticalGradient(
                colors: [.black, .black.opacity(0.6), .black.opacity(0)],
                center: .top,
                startRadiusFraction: 0,
                endRadiusFraction: 0.5
            )
            .frame(width: layout.topBlendWidth, height: min(2 * layout.topBlendHeight, size.height))
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }
}

struct BackgroundMediaView: View {
    let source: MediaSource
    let crop: MediaCrop
    let size: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if source.kind == .image, let image = MediaImageCache.cachedImage(at: source.url) {
                CroppedImageView(image: image, crop: crop, size: size)
            } else {
                MediaView(source: source, crop: crop, isActive: !reduceMotion)
                    .frame(width: size.width, height: size.height)
            }
        }
        .task(id: source.url) {
            guard source.kind == .image else { return }
            _ = await MediaImageCache.load(at: source.url)
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
    static let defaultMaxPixelSize = 1600
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 24
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func cachedImage(at url: URL, maxPixelSize: Int = defaultMaxPixelSize) -> NSImage? {
        cache.object(forKey: cacheKey(for: url, maxPixelSize: maxPixelSize))
    }

    static func load(at url: URL, maxPixelSize: Int = defaultMaxPixelSize) async -> NSImage? {
        let key = cacheKey(for: url, maxPixelSize: maxPixelSize)
        if let cached = cache.object(forKey: key) { return cached }
        let cgImage = await Task.detached(priority: .userInitiated) {
            decodeCGImage(at: url, maxPixelSize: maxPixelSize)
        }.value
        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }

    static func image(at url: URL, maxPixelSize: Int = defaultMaxPixelSize) -> NSImage? {
        let key = cacheKey(for: url, maxPixelSize: maxPixelSize)
        if let cached = cache.object(forKey: key) { return cached }
        guard let cgImage = decodeCGImage(at: url, maxPixelSize: maxPixelSize) else {
            return NSImage(contentsOf: url)
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }

    private static func cacheKey(for url: URL, maxPixelSize: Int) -> NSString {
        let stamp = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate?.timeIntervalSinceReferenceDate) ?? 0
        return "\(url.absoluteString)#\(maxPixelSize)#\(stamp)" as NSString
    }

    private nonisolated static func decodeCGImage(at url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
