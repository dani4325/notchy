import AppKit
import SwiftUI

enum SegmentedLevel {
    static let count = Int(VolumeStep.steps)
    static let lightnessSpread = 0.16
    static let gapRatio: CGFloat = 0.45
    static let change: TimeInterval = 0.12
    static let cascadeStep: TimeInterval = 0.018

    static func litSegments(for level: Float) -> Int {
        guard level > 0 else { return 0 }
        return min(count, max(1, Int((level * Float(count)).rounded())))
    }

    static func colors(accent: HexColor, panel: HexColor, awayFrom scrim: RGB) -> [HexColor] {
        let base = OKLCH(ContrastCorrection.corrected(accent, against: panel, for: .graphic).rgb)
        let direction = OKLCH(scrim).lightness < base.lightness ? 1.0 : -1.0
        return (0..<count).map { index in
            let position = Double(index) / Double(count - 1)
            let shade = OKLCH(
                lightness: (base.lightness + direction * lightnessSpread * position).clamped(to: 0...1),
                chroma: base.chroma,
                hue: base.hue
            ).mappedIntoSRGB()
            return ContrastCorrection.corrected(HexColor(rgb: shade.rgb), against: panel, for: .graphic)
        }
    }
}

struct SegmentedLevelBar: NSViewRepresentable {
    let level: Float
    let colors: [HexColor]
    let track: NSColor
    let nudge: VolumeNudge?

    func makeNSView(context: Context) -> SegmentedLevelView {
        SegmentedLevelView()
    }

    func updateNSView(_ view: SegmentedLevelView, context: Context) {
        let reduceMotion = context.environment.accessibilityReduceMotion
        let isNewNudge = nudge.map { $0.count != view.lastNudge } ?? false
        view.lastNudge = nudge?.count ?? view.lastNudge
        let cascade = isNewNudge && !reduceMotion && (nudge?.direction == .mute || nudge?.direction == .unmute)
        view.update(lit: SegmentedLevel.litSegments(for: level), colors: colors.map(\.nsColor), track: track,
                    style: reduceMotion ? .instant : cascade ? .cascade : .fade)
        if isNewNudge, !reduceMotion, let limit = nudge?.limit {
            view.stretch(toward: limit)
        }
    }
}

final class SegmentedLevelView: NSView {
    enum Style {
        case instant
        case fade
        case cascade
    }

    static let stretchScale = 1.05
    static let stretchOut: TimeInterval = 0.07

    var lastNudge = 0
    let rowLayer = CALayer()
    private var segments: [CALayer] = []
    private var lit = 0
    private var colors: [NSColor] = []
    private var track = NSColor.clear

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(rowLayer)
        segments = (0..<SegmentedLevel.count).map { _ in
            let segment = CALayer()
            segment.actions = ["backgroundColor": NSNull(), "bounds": NSNull(), "position": NSNull()]
            rowLayer.addSublayer(segment)
            return segment
        }
    }

    required init?(coder: NSCoder) { nil }

    func update(lit newLit: Int, colors newColors: [NSColor], track newTrack: NSColor, style: Style) {
        let previous = lit
        lit = newLit
        colors = newColors
        track = newTrack
        let now = CACurrentMediaTime()
        let turningOff = newLit < previous
        for (index, segment) in segments.enumerated() {
            let target = color(at: index).cgColor
            guard style != .instant, let current = segment.backgroundColor, current != target else {
                segment.backgroundColor = target
                continue
            }
            let fade = CABasicAnimation(keyPath: "backgroundColor")
            fade.fromValue = current
            fade.toValue = target
            fade.duration = SegmentedLevel.change
            if style == .cascade {
                let order = turningOff ? previous - 1 - index : index - previous
                fade.beginTime = now + Double(max(order, 0)) * SegmentedLevel.cascadeStep
                fade.fillMode = .backwards
            }
            segment.backgroundColor = target
            segment.add(fade, forKey: "fade")
        }
    }

    private func color(at index: Int) -> NSColor {
        index < lit && index < colors.count ? colors[index] : track
    }

    func stretch(toward limit: VolumeLimit) {
        let anchor = CGPoint(x: limit == .top ? 0 : 1, y: 0.5)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rowLayer.anchorPoint = anchor
        rowLayer.position = CGPoint(x: bounds.width * anchor.x, y: bounds.midY)
        CATransaction.commit()

        let out = CABasicAnimation(keyPath: "transform.scale.x")
        out.fromValue = 1
        out.toValue = Self.stretchScale
        out.duration = Self.stretchOut
        out.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let back = CASpringAnimation(keyPath: "transform.scale.x")
        back.fromValue = Self.stretchScale
        back.toValue = 1
        back.mass = 0.5
        back.stiffness = 400
        back.damping = 14
        back.beginTime = Self.stretchOut
        back.duration = back.settlingDuration
        let group = CAAnimationGroup()
        group.animations = [out, back]
        group.duration = Self.stretchOut + back.settlingDuration
        rowLayer.add(group, forKey: "stretch")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rowLayer.bounds = bounds
        rowLayer.position = CGPoint(x: bounds.width * rowLayer.anchorPoint.x, y: bounds.midY)
        let count = CGFloat(segments.count)
        let width = bounds.width / (count + (count - 1) * SegmentedLevel.gapRatio)
        let gap = width * SegmentedLevel.gapRatio
        for (index, segment) in segments.enumerated() {
            segment.frame = CGRect(x: CGFloat(index) * (width + gap), y: 0, width: width, height: bounds.height)
            segment.cornerRadius = min(width, bounds.height) / 2
        }
        CATransaction.commit()
    }
}

extension HexColor {
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
}
