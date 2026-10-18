import AppKit
import Observation
import SwiftUI

@MainActor
final class IslandPanelController {
    private static let openDelay: Duration = .milliseconds(90)
    private static let closeDelay: Duration = .milliseconds(180)

    private let panel: NotchPanel
    private let model: IslandModel
    private let nowPlaying: NowPlayingStore
    private let companion: CompanionStore
    private let wings: WingsVisibility
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
        nowPlaying: NowPlayingStore,
        companion: CompanionStore,
        wings: WingsVisibility
    ) {
        self.collapsedFrame = collapsedFrame
        self.screenFrame = screenFrame
        self.nowPlaying = nowPlaying
        self.companion = companion
        self.wings = wings
        model = IslandModel(kind: kind, collapsedSize: collapsedFrame.size)
        panel = NotchPanel(frame: collapsedFrame)

        let hostingView = HoverHostingView(rootView: IslandView(model: model, nowPlaying: nowPlaying, companion: companion))
        hostingView.onHoverChange = { [weak self] isInside in
            self?.hoverChanged(isInside)
        }
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        observeWings()
        transition(to: restingState, animated: false)
    }

    func update(collapsedFrame: CGRect, kind: IslandKind, screenFrame: CGRect) {
        cancelPending()
        self.collapsedFrame = collapsedFrame
        self.screenFrame = screenFrame
        model.kind = kind
        model.collapsedSize = collapsedFrame.size
        isHovering = false
        model.state = restingState
        panel.setFrame(frame(for: model.state), display: true)
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

        let policy = MotionPolicy.current
        model.reduceMotion = policy.reduceMotion
        let targetFrame = frame(for: target)
        let isGrowing = target > model.state

        panel.setFrame(panel.frame.union(targetFrame), display: true)
        let animation = animated ? policy.shapeAnimation(expanding: isGrowing) : nil
        withAnimation(animation) {
            model.state = target
        }

        guard animation != nil else {
            panel.setFrame(targetFrame, display: true)
            return
        }
        let settle = isGrowing ? MotionPolicy.openDuration : MotionPolicy.closeDuration
        pendingResize = Task { [weak self] in
            try? await Task.sleep(for: settle)
            guard !Task.isCancelled, let self, self.model.state == target else { return }
            self.panel.setFrame(targetFrame, display: true)
        }
    }

    private func frame(for state: IslandState) -> CGRect {
        switch state {
        case .collapsed:
            collapsedFrame
        case .compact:
            NotchGeometry.compactFrame(collapsed: collapsedFrame, wing: model.compactWing)
        case .expanded:
            NotchGeometry.expandedFrame(collapsed: collapsedFrame, size: IslandModel.expandedSize, screen: screenFrame)
        }
    }

    private func cancelPending() {
        pendingHover?.cancel()
        pendingResize?.cancel()
    }
}
