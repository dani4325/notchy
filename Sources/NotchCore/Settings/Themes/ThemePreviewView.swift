import SwiftUI

struct ThemePreviewView: View {
    let editor: ThemeEditorModel
    let theme: Theme
    let nowPlaying: NowPlayingStore

    private static let sample = NowPlayingInfo(
        title: String(localized: "Canción de ejemplo"), artist: String(localized: "Tu artista favorito"), album: nil, duration: 214,
        elapsed: 71, timestamp: .now, playbackRate: 0, isPlaying: false, appBundleID: "", artworkData: nil
    )

    private static let scale: CGFloat = 0.78

    var body: some View {
        VStack(spacing: 10) {
            toolbar
            let size = editor.previewModel.expandedSize
            island
                .frame(width: size.width, height: size.height, alignment: .top)
                .scaleEffect(Self.scale, anchor: .top)
                .frame(width: size.width * Self.scale, height: size.height * Self.scale, alignment: .top)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(white: 0.16), Color(white: 0.09)], startPoint: .top, endPoint: .bottom)
        )
        .environment(\.colorScheme, .dark)
    }

    private var island: some View {
        let appearance = ThemeAppearance.resolve(theme, in: editor.store)
        let model = editor.previewModel
        let size = model.currentSize
        let layout = model.layout

        let policy = MotionPolicy(reduceMotion: model.reduceMotion, openAnimation: theme.openAnimation)

        return ZStack(alignment: .top) {
            IslandSurface(model: model, appearance: appearance, showOutline: false)
            Group {
            if model.isExpanded {
                ExpandedMusicView(
                    layout: layout,
                    info: nowPlaying.info ?? Self.sample,
                    artwork: nowPlaying.info == nil ? nil : nowPlaying.artwork,
                    appName: nowPlaying.info == nil ? String(localized: "Vista previa") : nowPlaying.appName,
                    controls: .inert
                )
                .allowsHitTesting(false)
                .padding(.top, layout.stem.height)
                .transition(.opacity)
            }
            }
            .modifier(SignatureOpening(
                kind: theme.openAnimation, trigger: model.openCount, isEnabled: policy.playsSignatureOpening,
                layout: layout, appearance: appearance
            ))
            if model.isExpanded, theme.background != nil {
                framingSurface(bodySize: layout.bodyRect.size)
                    .padding(.top, layout.stem.height)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .environment(\.themeAppearance, appearance)
    }

    private func framingSurface(bodySize: CGSize) -> some View {
        Color.clear
            .frame(width: bodySize.width, height: bodySize.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { editor.dragBackground(by: $0.translation, displayedSize: bodySize) }
                    .onEnded { _ in editor.endBackgroundDrag() }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { editor.zoomBackground(by: $0.magnification) }
                    .onEnded { _ in editor.endBackgroundZoom() }
            )
            .onHover { inside in
                inside ? NSCursor.openHand.push() : NSCursor.pop()
            }
            .accessibilityLabel("Encuadre del fondo")
            .accessibilityHint("Arrastra para mover la imagen y pellizca para acercarla")
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text(theme.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            if let message = editor.message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: editor.replayOpening) {
                Label("Probar apertura", systemImage: "play.circle")
            }
            if editor.isEditingActiveTheme {
                Label("En uso", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(NotchyStyle.accent)
            } else {
                Button("Usar este tema", action: editor.activate)
                    .buttonStyle(.borderedProminent)
            }
        }
        .font(.system(size: 12))
    }
}
