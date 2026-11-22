import SwiftUI

struct PatternDecoration: View {
    let decoration: ThemeDecoration
    let unit: CGFloat
    let accent: Color
    let secondary: Color

    private static let faint = 0.12

    var body: some View {
        Canvas { context, size in
            let line = max(unit * 0.03, 0.7)
            let b = GraphicsContext.Shading.color(secondary.opacity(Self.faint))
            switch decoration {
            case .stripes:
                let stripe = unit * 0.5
                var x = -size.height
                while x < size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    context.stroke(path, with: b, lineWidth: stripe * 0.35)
                    x += stripe
                }
            case .grid:
                let step = unit * 0.6
                var grid = Path()
                stride(from: 0, through: size.width, by: step).forEach { grid.move(to: CGPoint(x: $0, y: 0)); grid.addLine(to: CGPoint(x: $0, y: size.height)) }
                stride(from: 0, through: size.height, by: step).forEach { grid.move(to: CGPoint(x: 0, y: $0)); grid.addLine(to: CGPoint(x: size.width, y: $0)) }
                context.stroke(grid, with: b, lineWidth: line * 0.6)
            case .zigzag:
                let tooth = unit * 0.32
                var teeth = Path()
                teeth.move(to: CGPoint(x: 0, y: size.height))
                var x: CGFloat = 0
                while x < size.width {
                    teeth.addLine(to: CGPoint(x: x + tooth / 2, y: size.height - tooth * 0.75))
                    teeth.addLine(to: CGPoint(x: x + tooth, y: size.height))
                    x += tooth
                }
                teeth.closeSubpath()
                context.fill(teeth, with: .color(accent.opacity(0.22)))
                context.stroke(Path(CGRect(x: 0, y: size.height - tooth * 0.95, width: size.width, height: 0.1)), with: .color(secondary.opacity(0.15)), lineWidth: line)
            case .waves:
                for row in 0..<3 {
                    var wave = Path()
                    let baseline = size.height - CGFloat(row) * unit * 0.35 - unit * 0.15
                    wave.move(to: CGPoint(x: 0, y: baseline))
                    var x: CGFloat = 0
                    while x < size.width {
                        wave.addQuadCurve(to: CGPoint(x: x + unit * 0.8, y: baseline), control: CGPoint(x: x + unit * 0.4, y: baseline - unit * 0.22))
                        x += unit * 0.8
                    }
                    context.stroke(wave, with: .color(accent.opacity(0.18 - Double(row) * 0.04)), lineWidth: line * 1.3)
                }
            case .rings:
                let center = CGPoint(x: size.width * 0.84, y: size.height * 0.55)
                for ring in 1...5 {
                    var wobble = Path()
                    for step in 0...72 {
                        let angle = Double(step) / 72 * 2 * .pi
                        let radius = CGFloat(ring) * unit * 0.42 + sin(angle * 6 + Double(ring)) * unit * 0.06
                        let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                        step == 0 ? wobble.move(to: point) : wobble.addLine(to: point)
                    }
                    context.stroke(wobble, with: ring.isMultiple(of: 2) ? .color(accent.opacity(0.2)) : .color(secondary.opacity(0.18)), lineWidth: line * 1.2)
                }
            case .ruled:
                var lines = Path()
                stride(from: unit * 0.5, to: size.height, by: unit * 0.42).forEach {
                    lines.move(to: CGPoint(x: 0, y: $0))
                    lines.addLine(to: CGPoint(x: size.width, y: $0))
                }
                context.stroke(lines, with: b, lineWidth: line * 0.6)
                context.stroke(Path(CGRect(x: unit * 0.35, y: 0, width: 0.1, height: size.height)), with: .color(accent.opacity(0.2)), lineWidth: line)
            default:
                break
            }
        }
    }
}
