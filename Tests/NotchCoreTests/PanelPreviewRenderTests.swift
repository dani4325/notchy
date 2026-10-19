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

    @Test func renderAllVariants() async throws {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let backgrounds = [("con-fondo", try Self.makeFaceImage()), ("fondo-blanco", try Self.makeSolidImage(white: 1))]

        for (name, notch) in Self.notches {
            try render(name: "\(name)-sin-fondo", notch: notch, theme: .notchyDefault, background: nil)

            var themed = Theme.notchyDefault
            themed.palette = ThemePalette(
                accent: HexColor("#7CF5C4")!, secondary: HexColor("#F5D27C")!,
                panel: HexColor("#120A1E")!, text: HexColor("#FFFFFF")!, source: .manual
            )
            for (suffix, url) in backgrounds {
                themed.background = ThemeBackground(
                    media: ThemeMedia(kind: .image, file: url.lastPathComponent, crop: MediaCrop(zoom: 1.4, focusX: 0.72, focusY: 0.3)),
                    legibility: 0
                )
                let source = MediaSource(url: url, kind: .image)
                await measureBackground(source, theme: themed, notch: notch)
                try render(name: "\(name)-\(suffix)", notch: notch, theme: themed, background: source)
            }
        }
    }

    private func measureBackground(_ source: MediaSource, theme: Theme, notch: CGSize) async {
        let model = IslandModel(kind: .notch, collapsedSize: notch, stripHeight: notch.height)
        model.shapeStyle = theme.shape
        model.state = .expanded
        let size = CGSize(width: model.currentSize.width, height: max(model.currentSize.height - model.stemHeight, 0))
        let key = BackgroundMeasurements.key(for: source, crop: theme.background!.media.crop, size: size, backdrop: ScrimPlan.backdrop)
        await BackgroundMeasurements.shared.measure(key)
    }

    @Test func renderAnimeTemplates() throws {
        FontRegistry.register(directory: RepoPaths.fonts)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let notch = IslandLayout.referenceNotch
        let playing = NowPlayingInfo(
            title: "Opening de la temporada", artist: "Artista de ejemplo", album: nil, duration: 245,
            elapsed: 83, timestamp: .now, playbackRate: 0, isPlaying: false, appBundleID: "", artworkData: nil
        )

        for theme in Theme.builtIns {
            let slug = theme.id.replacingOccurrences(of: "builtin-", with: "")
            try render(name: "plantilla-\(slug)", notch: notch, theme: theme, background: nil, info: playing)
            try render(name: "plantilla-\(slug)-apertura", notch: notch, theme: theme, background: nil, info: playing, openingProgress: 0.35)
        }
        try render(name: "plantilla-steins-gate-reposo", notch: notch, theme: .steinsGate, background: nil, info: nil)
    }

    @Test func renderChargingAnimation() throws {
        FontRegistry.register(directory: RepoPaths.fonts)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let cases: [(String, Theme, PowerEvent)] = [
            ("carga-notchy-conectado", .notchyDefault, .connected(percent: 78)),
            ("carga-steins-gate-conectado", .steinsGate, .connected(percent: 42)),
            ("carga-one-piece-desconectado-baja", .onePiece, .disconnected(percent: 14)),
            ("carga-frieren-bateria-baja", .frieren, .low(percent: 20)),
            ("carga-naruto-completa", .naruto, .full),
        ]
        for (name, theme, event) in cases {
            try render(name: name, notch: IslandLayout.referenceNotch, theme: theme, background: nil, power: event, info: nil)
        }
    }

    @Test func renderVisualizer() throws {
        FontRegistry.register(directory: RepoPaths.fonts)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let playing = NowPlayingInfo(
            title: "Opening de la temporada", artist: "Artista de ejemplo", album: nil, duration: 245,
            elapsed: 83, timestamp: .now, playbackRate: 1, isPlaying: true, appBundleID: "", artworkData: nil
        )
        for theme in [Theme.notchyDefault, .jujutsuKaisen, .violetEvergarden] {
            let slug = theme.id.replacingOccurrences(of: "builtin-", with: "")
            try render(name: "visualizador-\(slug)", notch: IslandLayout.referenceNotch, theme: theme, background: nil, info: playing)
        }
    }

    @Test func renderShelf() throws {
        FontRegistry.register(directory: RepoPaths.fonts)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("shelf-render-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let files = try ["Guion.pdf", "captura del notch.png", "notas de la reunión.txt", "Proyecto.zip"].map { name -> URL in
            let url = base.appendingPathComponent(name)
            try Data("x".utf8).write(to: url)
            return url
        }
        let empty = ShelfStore(directory: base.appendingPathComponent("empty"))
        let full = ShelfStore(directory: base.appendingPathComponent("full"))
        full.add(files)

        for (name, theme, store, targeted) in [
            ("estanteria-vacia-notchy", Theme.notchyDefault, empty, false),
            ("estanteria-soltando-frieren", Theme.frieren, empty, true),
            ("estanteria-archivos-one-piece", Theme.onePiece, full, false),
        ] {
            try render(name: name, notch: IslandLayout.referenceNotch, theme: theme, background: nil, shelf: (store, targeted), info: nil)
        }
    }

    @Test func renderPillOnMacsWithoutNotch() throws {
        FontRegistry.register(directory: RepoPaths.fonts)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let pill = CGSize(width: NotchGeometry.pillWidth, height: 20)
        let playing = NowPlayingInfo(
            title: "Opening de la temporada", artist: "Artista de ejemplo", album: nil, duration: 245,
            elapsed: 83, timestamp: .now, playbackRate: 1, isPlaying: true, appBundleID: "", artworkData: nil
        )
        let emptyShelf = ShelfStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("pill-\(UUID().uuidString)"))
        try render(name: "pildora-musica-chainsaw-man", notch: pill, theme: .chainsawMan, background: nil, pill: true, info: playing)
        try render(name: "pildora-estanteria-black-clover", notch: pill, theme: .blackClover, background: nil, shelf: (emptyShelf, true), pill: true, info: nil)
        try render(name: "pildora-volumen-eighty-six", notch: pill, theme: .eightySix, background: nil,
                   volume: VolumeReading(level: 0.375, isMuted: false), pill: true, info: nil)
    }

    @Test func renderOnboarding() async throws {
        FontRegistry.register(directory: RepoPaths.fonts)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "onboarding-render-\(UUID().uuidString)")!
        let store = ThemeStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ob-\(UUID().uuidString)"), defaults: defaults)
        let model = OnboardingModel(defaults: defaults)

        for step in OnboardingStep.allCases {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 640, height: 500), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            let host = NSHostingView(rootView: OnboardingView(model: model, accessibility: AccessibilityPermission(), loginItem: LoginItem(), themes: store))
            window.contentView = host
            window.orderFrontRegardless()
            for _ in 0..<6 {
                host.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(80))
            }
            let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            let png = try #require(rep.representation(using: .png, properties: [:]))
            try png.write(to: outputDirectory.appendingPathComponent("bienvenida-\(step.rawValue + 1).png"))
            window.orderOut(nil)
            model.next()
        }
        try render(name: "saludo-attack-on-titan", notch: IslandLayout.referenceNotch, theme: .attackOnTitan, background: nil, greeting: true, info: nil)
    }

    @Test func renderVolumeHUD() throws {
        FontRegistry.register(directory: RepoPaths.fonts)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let cases: [(String, Theme, VolumeReading)] = [
            ("volumen-notchy", .notchyDefault, VolumeReading(level: 0.5625, isMuted: false)),
            ("volumen-steins-gate", .steinsGate, VolumeReading(level: 0.8125, isMuted: false)),
            ("volumen-chainsaw-man-silencio", .chainsawMan, VolumeReading(level: 0.4, isMuted: true)),
        ]
        for (name, theme, reading) in cases {
            try render(name: name, notch: IslandLayout.referenceNotch, theme: theme, background: nil, volume: reading, info: nil)
        }
    }

    private func render(
        name: String, notch: CGSize, theme: Theme, background: MediaSource?, power: PowerEvent? = nil, volume: VolumeReading? = nil, shelf: (ShelfStore, Bool)? = nil, pill: Bool = false, greeting: Bool = false,
        info: NowPlayingInfo? = PanelPreviewRenderTests.info, openingProgress: Double? = nil
    ) throws {
        let model = IslandModel(kind: pill ? .pill : .notch, collapsedSize: notch, stripHeight: pill ? notch.height + 2 : notch.height)
        model.shapeStyle = theme.shape
        model.state = .expanded
        let layout = model.layout
        let appearance = ThemeAppearance(theme: theme, background: background)
        let margin = layout.unit * 1.5

        let scene = ZStack(alignment: .top) {
            LinearGradient(colors: [Color(white: 0.82), Color(white: 0.62)], startPoint: .top, endPoint: .bottom)
            Color(white: 0.93).frame(height: pill ? notch.height + 4 : notch.height)
            ZStack(alignment: .top) {
                IslandSurface(model: model, appearance: appearance, showOutline: false)
                Group {
                    if greeting {
                        GreetingView(layout: layout)
                    } else if let shelf {
                        ShelfView(layout: layout, shelf: shelf.0, isDropTargeted: shelf.1)
                    } else if let power {
                        ChargingView(layout: layout, event: power)
                    } else if let volume {
                        VolumeHUDView(layout: layout, reading: volume)
                    } else if let info {
                        ExpandedMusicView(layout: layout, info: info, artwork: nil, appName: "Spotify", controls: .inert)
                    } else {
                        IdleContentView(layout: layout)
                    }
                }
                .padding(.top, layout.stem.height)
                if let openingProgress {
                    if theme.openAnimation == .glitch {
                        GlitchLayer(
                            state: GlitchState.bursts[2], unit: layout.unit, tint: appearance.accent,
                            content: ExpandedMusicView(layout: layout, info: info ?? Self.info, artwork: nil, appName: "Spotify", controls: .inert)
                                .padding(.top, layout.stem.height)
                        )
                    } else {
                        SignatureOverlay(kind: theme.openAnimation, progress: openingProgress, layout: layout, appearance: appearance)
                    }
                }
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

    private static func makeSolidImage(white: Double) throws -> URL {
        let context = try #require(CGContext(
            data: nil, width: 800, height: 450, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: white, green: white, blue: white, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 450))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("solido-\(white).png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
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
