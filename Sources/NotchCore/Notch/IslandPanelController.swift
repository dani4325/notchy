import AppKit
import Observation
import SwiftUI

@MainActor
final class IslandPanelController {
    private static let openDelay: Duration = .milliseconds(90)
    private static let closeDelay: Duration = .milliseconds(180)

    private let panel: NotchPanel
    private let hostingView: HoverHostingView<IslandView>
    private let model: IslandModel
    private let nowPlaying: NowPlayingStore
    private let companion: CompanionStore
    private let wings: WingsVisibility
    private let themes: ThemeStore
    private var collapsedFrame: CGRect
    private var screenFrame: CGRect
    private var isHovering = false
    private var pendingHover: Task<Void, Never>?
    private var pendingResize: Task<Void, Never>?
    private var isClosed = false

    init(
        collapsedFrame: CGRect,
        kind: IslandKind,
        screenFrame: CGRect,
        stripHeight: CGFloat,
        nowPlaying: NowPlayingStore,
        companion: CompanionStore,
        wings: WingsVisibility,
        themes: ThemeStore
    ) {
        self.collapsedFrame = collapsedFrame
        self.screenFrame = screenFrame
        self.nowPlaying = nowPlaying
        self.companion = companion
        self.wings = wings
        self.themes = themes
        model = IslandModel(kind: kind, collapsedSize: collapsedFrame.size, stripHeight: stripHeight)
        panel = NotchPanel(frame: collapsedFrame)

        hostingView = HoverHostingView(rootView: IslandView(model: model, nowPlaying: nowPlaying, companion: companion, themes: themes))
        hostingView.onHoverChange = { [weak self] isInside in
            self?.hoverChanged(isInside)
        }
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        observeWings()
        observeTheme()
        transition(to: restingState, animated: false)
        refreshHoverRegions()
    }

    var wingZones: [CGRect] {
        NotchGeometry.wingZones(collapsed: collapsedFrame, wing: model.compactWing)
    }

    func update(collapsedFrame: CGRect, kind: IslandKind, screenFrame: CGRect, stripHeight: CGFloat) {
        cancelPending()
        self.collapsedFrame = collapsedFrame
        self.screenFrame = screenFrame
        model.kind = kind
        model.collapsedSize = collapsedFrame.size
        model.stripHeight = stripHeight
        isHovering = false
        model.state = restingState
        setPanelFrame(frame(for: model.state))
        panel.orderFrontRegardless()
    }

    func close() {
        isClosed = true
        cancelPending()
        panel.close()
    }

    private var restingState: IslandState {
        wings.isVisible ? .compact : .collapsed
    }

    private func observeWings() {
        withObservationTracking {
            _ = wings.isVisible
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !self.isClosed else { return }
                self.observeWings()
                if !self.isHovering {
                    self.transition(to: self.restingState, animated: true)
                }
            }
        }
    }

    private func observeTheme() {
        let theme = themes.activeTheme
        model.shapeStyle = theme.shape
        model.openAnimation = theme.openAnimation
        withObservationTracking {
            _ = themes.activeTheme
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !self.isClosed else { return }
                self.observeTheme()
                if self.model.isExpanded {
                    self.setPanelFrame(self.frame(for: .expanded))
                }
            }
        }
    }

    private func hoverChanged(_ isInside: Bool) {
        isHovering = isInside
        pendingHover?.cancel()
        let target = isInside ? IslandState.expanded : restingState
        guard target != model.state else { return }

        let delay = isInside ? Self.openDelay : Self.closeDelay
        pendingHover = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.transition(to: self.isHovering ? .expanded : self.restingState, animated: true)
        }
    }

    private func transition(to target: IslandState, animated: Bool) {
        guard target != model.state || panel.frame != frame(for: target) else { return }
        pendingResize?.cancel()

        let policy = MotionPolicy.current(openAnimation: model.openAnimation)
        model.reduceMotion = policy.reduceMotion
        let targetFrame = frame(for: target)
        let isGrowing = target > model.state

        setPanelFrame(panel.frame.union(targetFrame))
        let animation = animated ? policy.shapeAnimation(expanding: isGrowing) : nil
        withAnimation(animation) {
            model.state = target
        }
        refreshHoverRegions()

        guard animation != nil else {
            setPanelFrame(targetFrame)
            return
        }
        let settle = isGrowing ? MotionPolicy.openDuration : MotionPolicy.closeDuration
        pendingResize = Task { [weak self] in
            try? await Task.sleep(for: settle)
            guard !Task.isCancelled, let self, self.model.state == target else { return }
            self.setPanelFrame(targetFrame)
        }
    }

    private func setPanelFrame(_ frame: CGRect) {
        panel.setFrame(frame, display: true)
        refreshHoverRegions()
    }

    private func refreshHoverRegions() {
        hostingView.setHoverRegions(NotchGeometry.hoverRegions(
            expanded: model.isExpanded,
            collapsed: collapsedFrame,
            expandedFrame: frame(for: .expanded),
            stripHeight: model.stripHeight
        ))
    }

    private func frame(for state: IslandState) -> CGRect {
        switch state {
        case .collapsed:
            collapsedFrame
        case .compact:
            NotchGeometry.compactFrame(collapsed: collapsedFrame, wing: model.compactWing)
        case .expanded:
            NotchGeometry.expandedFrame(collapsed: collapsedFrame, size: model.expandedSize, screen: screenFrame)
        }
    }

    private func cancelPending() {
        pendingHover?.cancel()
        pendingResize?.cancel()
    }
}
