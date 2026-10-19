import AppKit
import SwiftUI

struct SpectrumBars: NSViewRepresentable {
    var source: AudioVisualizer?
    var levels: [Float] = []
    let color: NSColor
    let height: CGFloat

    func makeNSView(context: Context) -> SpectrumBarsView {
        let view = SpectrumBarsView()
        if let source { view.observe(source) }
        return view
    }

    func updateNSView(_ view: SpectrumBarsView, context: Context) {
        view.color = color
        view.animated = !context.environment.accessibilityReduceMotion
        view.update(levels: source?.levels ?? levels)
    }

    static func dismantleNSView(_ view: SpectrumBarsView, coordinator: ()) {
        view.stopObserving()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: SpectrumBarsView, context: Context) -> CGSize? {
        let count = CGFloat(max(source.map { _ in SystemAudioTap.bandCount } ?? levels.count, 1))
        return CGSize(width: count * height * SpectrumBarsView.barRatio + (count - 1) * height * SpectrumBarsView.gapRatio, height: height)
    }
}

final class SpectrumBarsView: NSView {
    static let barRatio: CGFloat = 0.2
    static let gapRatio: CGFloat = 0.16
    static let minimumLevel: CGFloat = 0.14
    static let transition: TimeInterval = 0.06

    var color = NSColor.white
    var animated = true
    private var bars: [CALayer] = []
    private var levels: [Float] = []
    private weak var source: AudioVisualizer?
    private var subscription: UUID?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    func observe(_ visualizer: AudioVisualizer) {
        source = visualizer
        subscription = visualizer.observeLevels { [weak self] in self?.update(levels: $0) }
    }

    func stopObserving() {
        if let subscription { source?.stopObservingLevels(subscription) }
        subscription = nil
    }

    func update(levels newLevels: [Float]) {
        levels = newLevels
        if bars.count != levels.count {
            bars.forEach { $0.removeFromSuperlayer() }
            bars = levels.map { _ in CALayer() }
            bars.forEach { layer?.addSublayer($0) }
        }
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(Self.transition)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
        } else {
            CATransaction.setDisableActions(true)
        }
        for (bar, level) in zip(bars, levels) {
            bar.backgroundColor = color.cgColor
            bar.frame = frame(for: bar, level: level)
        }
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (bar, level) in zip(bars, levels) {
            bar.frame = frame(for: bar, level: level)
        }
        CATransaction.commit()
    }

    private func frame(for bar: CALayer, level: Float) -> CGRect {
        let side = bounds.height
        let index = CGFloat(bars.firstIndex { $0 === bar } ?? 0)
        let width = side * Self.barRatio
        let height = max(side * CGFloat(level), side * Self.minimumLevel)
        bar.cornerRadius = width / 2
        return CGRect(x: index * (width + side * Self.gapRatio), y: 0, width: width, height: height)
    }
}
