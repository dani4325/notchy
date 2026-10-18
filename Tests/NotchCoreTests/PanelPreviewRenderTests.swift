import AppKit
import SwiftUI
import Testing
@testable import NotchCore

@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["NOTCHY_PREVIEW_DIR"] != nil))
struct PanelPreviewRenderTests {
    static let notches: [(String, CGSize)] = [
        ("notch-185x32", CGSize(width: 185, height: 32)),
        ("notch-208x37", CGSize(width: 208, height: 37.5)),
        ("notch-232x41", CGSize(width: 232, height: 41)),
    ]

    static let info = NowPlayingInfo(
        title: "Un título larguísimo que no cabe de ninguna manera en el panel expandido",
        artist: "Artista con un nombre también bastante largo para probar el truncado",
        album: nil, duration: 245, elapsed: 83, timestamp: .now, playbackRate: 0,
        isPlaying: false, appBundleID: "", artworkData: nil
    )

    let outputDirectory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["NOTCHY_PREVIEW_DIR"] ?? "/tmp")

    @Test func renderAllVariants() throws {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let backgroundURL = try Self.makeFaceImage()

        for (name, notch) in Self.notches {
            try render(name: "\(name)-sin-fondo", notch: notch, theme: .notchyDefault, background: nil)

            var themed = Theme.notchyDefault
            themed.palette = ThemePalette(
                accent: HexColor("#7CF5C4")!, secondary: HexColor("#F5D27C")!,
                panel: HexColor("#120A1E")!, text: HexColor("#FFFFFF")!, source: .manual
            )
            themed.background = ThemeBackground(
                media: ThemeMedia(kind: .image, file: "face.png", crop: MediaCrop(zoom: 1.4, focusX: 0.72, focusY: 0.3)),
                legibility: ThemeBackground.legibilityRange.lowerBound
            )
            try render(name: "\(name)-con-fondo", notch: notch, theme: themed,
                       background: MediaSource(url: backgroundURL, kind: .image))
        }
    }

    private func render(name: String, notch: CGSize, theme: Theme, background: MediaSource?) throws {
        let model = IslandModel(kind: .notch, collapsedSize: notch, stripHeight: notch.height)
        model.shapeStyle = theme.shape
        model.state = .expanded
        let layout = model.layout
        let appearance = ThemeAppearance(theme: theme, background: background)
        let margin = layout.unit * 1.5

        let scene = ZStack(alignment: .top) {
            LinearGradient(colors: [Color(white: 0.82), Color(white: 0.62)], startPoint: .top, endPoint: .bottom)
            Color(white: 0.93).frame(height: notch.height)
            ZStack(alignment: .top) {
                IslandSurface(model: model, appearance: appearance, showOutline: false)
                ExpandedMusicView(layout: layout, info: Self.info, artwork: nil, appName: "Spotify", controls: .inert)
                    .padding(.top, layout.stem.height)
            }
            .frame(width: layout.size.width, height: layout.size.height, alignment: .top)
            .environment(\.themeAppearance, appearance)
        }
        .frame(width: layout.size.width + 2 * margin, height: layout.size.height + margin)

        let renderer = ImageRenderer(content: scene)
        renderer.scale = 2
        let image = try #require(renderer.nsImage)
        let tiff = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: tiff))
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: outputDirectory.appendingPathComponent("\(name).png"))
    }

    private static func makeFaceImage() throws -> URL {
        let size = CGSize(width: 1600, height: 900)
        let context = try #require(CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [CGColor(srgbRed: 0.95, green: 0.55, blue: 0.75, alpha: 1), CGColor(srgbRed: 0.98, green: 0.95, blue: 0.85, alpha: 1)] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        let face = CGRect(x: 0.72 * size.width - 120, y: (1 - 0.3) * size.height - 120, width: 240, height: 240)
        context.setFillColor(CGColor(srgbRed: 1, green: 0.85, blue: 0.7, alpha: 1))
        context.fillEllipse(in: face)
        context.setFillColor(CGColor(srgbRed: 0.15, green: 0.1, blue: 0.2, alpha: 1))
        context.fillEllipse(in: CGRect(x: face.minX + 60, y: face.midY + 20, width: 30, height: 30))
        context.fillEllipse(in: CGRect(x: face.maxX - 90, y: face.midY + 20, width: 30, height: 30))
        context.setStrokeColor(CGColor(srgbRed: 0.15, green: 0.1, blue: 0.2, alpha: 1))
        context.setLineWidth(10)
        context.addArc(center: CGPoint(x: face.midX, y: face.midY - 20), radius: 50, startAngle: .pi * 1.15, endAngle: .pi * 1.85, clockwise: false)
        context.strokePath()

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-face-\(UUID().uuidString).png")
        let cgImage = try #require(context.makeImage())
        let png = try #require(NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]))
        try png.write(to: url)
        return url
    }
}
