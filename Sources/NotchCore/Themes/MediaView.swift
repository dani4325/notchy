import AppKit
import AVFoundation
import os
import QuartzCore
import SwiftUI

struct MediaView: NSViewRepresentable {
    let source: MediaSource
    var crop: MediaCrop = .standard
    let isActive: Bool

    func makeNSView(context: Context) -> MediaContainerView {
        MediaContainerView()
    }

    func updateNSView(_ view: MediaContainerView, context: Context) {
        view.configure(source: source, crop: crop, isActive: isActive)
    }

    static func dismantleNSView(_ view: MediaContainerView, coordinator: ()) {
        view.tearDown()
    }
}

final class MediaContainerView: NSView {
    static let frameAnimationKey = "notchy.frames"

    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "media")
    private static let posterTime = CMTime(seconds: 0.5, preferredTimescale: 600)
    private static let decodePixelSize = 1400

    private var source: MediaSource?
    private var crop = MediaCrop.standard
    private var isActive = false
    private var mediaAspect: Double = 1
    private(set) var imageView: NSView?
    private var playerView: NSView?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private(set) var loadTask: Task<Void, Never>?

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(source: MediaSource, crop: MediaCrop, isActive: Bool) {
        if source != self.source {
            tearDown()
            self.source = source
            self.isActive = isActive
            load(source)
        }
        if crop != self.crop {
            self.crop = crop
            needsLayout = true
        }
        setActive(isActive)
    }

    func tearDown() {
        loadTask?.cancel()
        loadTask = nil
        player?.pause()
        looper?.disableLooping()
        looper = nil
        player = nil
        playerView?.removeFromSuperview()
        playerView = nil
        imageView?.removeFromSuperview()
        imageView = nil
        source = nil
        isActive = false
    }

    override func layout() {
        super.layout()
        guard bounds.width > 0, bounds.height > 0 else { return }
        let window = crop.rect(mediaAspect: mediaAspect, targetAspect: bounds.width / bounds.height)
        let contentFrame = CGRect(
            x: -window.minX / window.width * bounds.width,
            y: -window.minY / window.height * bounds.height,
            width: bounds.width / window.width,
            height: bounds.height / window.height
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageView?.frame = contentFrame
        playerView?.frame = contentFrame
        playerView?.layer?.sublayers?.forEach { $0.frame = playerView?.bounds ?? .zero }
        CATransaction.commit()
    }

    private func load(_ source: MediaSource) {
        let url = source.url
        switch source.kind {
        case .image, .animatedImage:
            let maxPixelSize = Self.decodePixelSize
            loadTask = Task { @MainActor [weak self] in
                let decoded = await Task.detached(priority: .userInitiated) {
                    AnimatedImageDecoder.decode(url: url, maxPixelSize: maxPixelSize)
                }.value
                guard !Task.isCancelled, let self, self.source?.url == url else { return }
                guard let decoded else {
                    Self.logger.error("image decode failed: \(url.lastPathComponent, privacy: .public)")
                    return
                }
                self.show(decoded, animated: source.kind == .animatedImage)
            }
        case .video:
            loadTask = Task { @MainActor [weak self] in
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                do {
                    let frame = try await generator.image(at: Self.posterTime).image
                    guard !Task.isCancelled, let self, self.source?.url == url else { return }
                    self.show(DecodedAnimation(frames: [frame], delays: [1]), animated: false)
                    self.imageView?.isHidden = self.isActive
                } catch {
                    Self.logger.error("poster failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func show(_ decoded: DecodedAnimation, animated: Bool) {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.contentsGravity = .resize
        view.layer?.contents = decoded.frames.first
        addSubview(view, positioned: .below, relativeTo: playerView)
        imageView = view
        mediaAspect = decoded.aspect

        if animated, decoded.frames.count > 1, let layer = view.layer {
            let animation = CAKeyframeAnimation(keyPath: "contents")
            animation.values = decoded.frames
            animation.keyTimes = decoded.keyTimes.map { NSNumber(value: $0) }
            animation.calculationMode = .discrete
            animation.duration = decoded.duration
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: Self.frameAnimationKey)
            isActive ? resume(layer) : pause(layer)
        }
        needsLayout = true
    }

    private func setActive(_ active: Bool) {
        guard active != isActive, let source else { return }
        isActive = active
        switch source.kind {
        case .image:
            break
        case .animatedImage:
            guard let layer = imageView?.layer, layer.animation(forKey: Self.frameAnimationKey) != nil else { return }
            active ? resume(layer) : pause(layer)
        case .video:
            if active {
                startVideo(source.url)
            } else {
                player?.pause()
            }
        }
    }

    private func pause(_ layer: CALayer) {
        guard layer.speed != 0 else { return }
        let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = pausedTime
    }

    private func resume(_ layer: CALayer) {
        guard layer.speed == 0 else { return }
        let pausedTime = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        layer.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
    }

    private func startVideo(_ url: URL) {
        if player == nil {
            let queue = AVQueuePlayer()
            queue.isMuted = true
            queue.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))

            let view = NSView()
            view.wantsLayer = true
            let playerLayer = AVPlayerLayer(player: queue)
            playerLayer.videoGravity = .resize
            view.layer?.addSublayer(playerLayer)
            addSubview(view)
            playerView = view
            player = queue
            needsLayout = true
        }
        imageView?.isHidden = true
        player?.play()
    }
}
