import AppKit
import SwiftUI

struct LevelBar: NSViewRepresentable {
    let fraction: Double
    let fill: NSColor
    let track: NSColor
    let height: CGFloat
    var transition: TimeInterval = 0.15

    func makeNSView(context: Context) -> LevelBarView {
        LevelBarView()
    }

    func updateNSView(_ view: LevelBarView, context: Context) {
        let reduceMotion = context.environment.accessibilityReduceMotion
        view.update(fraction: fraction, fill: fill, track: track, duration: reduceMotion ? 0 : transition)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: LevelBarView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: height)
    }
}

final class LevelBarView: NSView {
    let barLayer = CALayer()
    private let trackLayer = CALayer()
    private let fillLayer = CALayer()
    private var fraction = 0.0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(barLayer)
        barLayer.addSublayer(trackLayer)
        barLayer.addSublayer(fillLayer)
    }

    required init?(coder: NSCoder) { nil }

    func update(fraction newFraction: Double, fill: NSColor, track: NSColor, duration: TimeInterval) {
        fraction = min(max(newFraction, 0), 1)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.backgroundColor = track.cgColor
        fillLayer.backgroundColor = fill.cgColor
        fillLayer.isHidden = fraction == 0
        CATransaction.commit()
        CATransaction.begin()
        if duration > 0 {
            CATransaction.setAnimationDuration(duration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
        } else {
            CATransaction.setDisableActions(true)
        }
        fillLayer.frame = fillFrame
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let radius = bounds.height / 2
        barLayer.bounds = bounds
        barLayer.position = CGPoint(x: bounds.width * barLayer.anchorPoint.x, y: bounds.midY)
        trackLayer.frame = bounds
        trackLayer.cornerRadius = radius
        fillLayer.cornerRadius = radius
        fillLayer.frame = fillFrame
        CATransaction.commit()
    }

    private var fillFrame: CGRect {
        let width = fraction > 0 ? max(bounds.width * fraction, bounds.height) : 0
        return CGRect(x: 0, y: 0, width: width, height: bounds.height)
    }
}
