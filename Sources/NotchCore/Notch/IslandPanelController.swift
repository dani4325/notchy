import AppKit
import SwiftUI

@MainActor
final class IslandPanelController {
    private static let openDelay: Duration = .milliseconds(90)
    private static let closeDelay: Duration = .milliseconds(180)

    private let panel: NotchPanel
    private let model: IslandModel
    private var collapsedFrame: CGRect
    private var screenFrame: CGRect
    private var pendingHover: Task<Void, Never>?
    private var pendingShrink: Task<Void, Never>?

    init(collapsedFrame: CGRect, kind: IslandKind, screenFrame: CGRect) {
        self.collapsedFrame = collapsedFrame
        self.screenFrame = screenFrame
        model = IslandModel(kind: kind, collapsedSize: collapsedFrame.size)
        panel = NotchPanel(frame: collapsedFrame)

        let hostingView = HoverHostingView(rootView: IslandView(model: model))
        hostingView.onHoverChange = { [weak self] isInside in
            self?.hoverChanged(isInside)
        }
        panel.contentView = hostingView
        panel.orderFrontRegardless()
    }

    func update(collapsedFrame: CGRect, kind: IslandKind, screenFrame: CGRect) {
        cancelPending()
        self.collapsedFrame = collapsedFrame
        self.screenFrame = screenFrame
        model.kind = kind
        model.collapsedSize = collapsedFrame.size
        model.isExpanded = false
        panel.setFrame(collapsedFrame, display: true)
        panel.orderFrontRegardless()
    }

    func close() {
        cancelPending()
        panel.close()
    }

    private func hoverChanged(_ isInside: Bool) {
        pendingHover?.cancel()
        guard isInside != model.isExpanded else { return }

        let delay = isInside ? Self.openDelay : Self.closeDelay
        pendingHover = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            isInside ? self?.expand() : self?.collapse()
        }
    }

    private func expand() {
        pendingShrink?.cancel()
        let policy = MotionPolicy.current
        model.reduceMotion = policy.reduceMotion

        let target = NotchGeometry.expandedFrame(
            collapsed: collapsedFrame,
            size: IslandModel.expandedSize,
            screen: screenFrame
        )
        panel.setFrame(target, display: true)
        withAnimation(policy.shapeAnimation(expanding: true)) {
            model.isExpanded = true
        }
    }

    private func collapse() {
        let policy = MotionPolicy.current
        model.reduceMotion = policy.reduceMotion

        withAnimation(policy.shapeAnimation(expanding: false)) {
            model.isExpanded = false
        }

        guard policy.animatesShape else {
            shrinkWindow()
            return
        }
        pendingShrink = Task { [weak self] in
            try? await Task.sleep(for: MotionPolicy.closeDuration)
            guard !Task.isCancelled else { return }
            self?.shrinkWindow()
        }
    }

    private func shrinkWindow() {
        guard !model.isExpanded else { return }
        panel.setFrame(collapsedFrame, display: true)
    }

    private func cancelPending() {
        pendingHover?.cancel()
        pendingShrink?.cancel()
    }
}
