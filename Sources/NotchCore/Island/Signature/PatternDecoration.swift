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
            let a = GraphicsContext.Shading.color(accent.opacity(Self.faint))
            let b = GraphicsContext.Shading.color(secondary.opacity(Self.faint))
            switch decoration {
            case .cracks:
                for (start, angle) in [(CGPoint(x: size.width, y: 0), 2.4), (CGPoint(x: 0, y: size.height), -0.8)] {
                    var path = Path()
                    var point = start
                    path.move(to: point)
                    for step in 0..<6 {
                        let bend = angle + (step.isMultiple(of: 2) ? 0.35 : -0.35)
                        point = CGPoint(x: point.x + cos(bend) * unit * 0.9, y: point.y + sin(bend) * unit * 0.9)
                        path.addLine(to: point)
                    }
                    context.stroke(path, with: .color(accent.opacity(0.28)), lineWidth: line * 1.4)
                }
            case .tacticalGrid:
                let step = unit * 0.6
                var grid = Path()
                stride(from: 0, through: size.width, by: step).forEach { grid.move(to: CGPoint(x: $0, y: 0)); grid.addLine(to: CGPoint(x: $0, y: size.height)) }
                stride(from: 0, through: size.height, by: step).forEach { grid.move(to: CGPoint(x: 0, y: $0)); grid.addLine(to: CGPoint(x: size.width, y: $0)) }
                context.stroke(grid, with: b, lineWidth: line * 0.6)
                let center = CGPoint(x: size.width * 0.9, y: size.height)
                for radius in [unit * 1.2, unit * 2.2, unit * 3.2] {
                    context.stroke(Path { $0.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) },
                                   with: .color(accent.opacity(0.22)), lineWidth: line)
                }
            case .clovers:
                for (index, spot) in [(0.9, 0.25), (0.78, 0.8), (0.06, 0.85)].enumerated() {
                    let center = CGPoint(x: size.width * spot.0, y: size.height * spot.1)
                    let leaf = unit * (0.32 - CGFloat(index) * 0.05)
                    for quarter in 0..<4 {
                        let angle = Double(quarter) * .pi / 2 + .pi / 4
                        let leafCenter = CGPoint(x: center.x + cos(angle) * leaf * 0.6, y: center.y + sin(angle) * leaf * 0.6)
                        context.fill(Path(ellipseIn: CGRect(x: leafCenter.x - leaf / 2, y: leafCenter.y - leaf / 2, width: leaf, height: leaf)), with: a)
                    }
                }
            case .cursedWisps:
                for index in 0..<4 {
                    var wisp = Path()
                    let x = size.width * (0.55 + CGFloat(index) * 0.12)
                    wisp.move(to: CGPoint(x: x, y: size.height))
                    wisp.addCurve(to: CGPoint(x: x + unit * 0.4, y: size.height * 0.15),
                                  control1: CGPoint(x: x - unit * 0.7, y: size.height * 0.65),
                                  control2: CGPoint(x: x + unit * 0.9, y: size.height * 0.45))
                    context.stroke(wisp, with: index.isMultiple(of: 2) ? .color(accent.opacity(0.22)) : .color(secondary.opacity(0.18)), lineWidth: line * 2.2)
                }
            case .sawTeeth:
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
            case .transmutation:
                let radius = min(size.width, size.height) * 0.44
                let center = CGPoint(x: size.width * 0.82, y: size.height * 0.5)
                context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: a, lineWidth: line)
                context.stroke(Path(ellipseIn: CGRect(x: center.x - radius * 0.82, y: center.y - radius * 0.82, width: radius * 1.64, height: radius * 1.64)), with: a, lineWidth: line)
                for rotation in [0.0, .pi] {
                    var triangle = Path()
                    for corner in 0..<3 {
                        let angle = rotation - .pi / 2 + Double(corner) * 2 * .pi / 3
                        let point = CGPoint(x: center.x + cos(angle) * radius * 0.82, y: center.y + sin(angle) * radius * 0.82)
                        corner == 0 ? triangle.move(to: point) : triangle.addLine(to: point)
                    }
                    triangle.closeSubpath()
                    context.stroke(triangle, with: a, lineWidth: line)
                }
            case .petals:
                for index in 0..<14 {
                    let seed = Double(index) * 7.31
                    let point = CGPoint(x: abs(sin(seed)) * size.width, y: abs(cos(seed * 1.3)) * size.height)
                    let petal = unit * 0.1
                    for leaf in 0..<5 {
                        let angle = Double(leaf) * 2 * .pi / 5
                        context.fill(Path(ellipseIn: CGRect(x: point.x + cos(angle) * petal - petal / 2, y: point.y + sin(angle) * petal - petal / 2, width: petal, height: petal)),
                                     with: index.isMultiple(of: 2) ? a : b)
                    }
                }
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
            case .spiral:
                var spiral = Path()
                let center = CGPoint(x: size.width * 0.86, y: size.height * 0.5)
                for step in 0...120 {
                    let angle = Double(step) * 0.16
                    let radius = CGFloat(step) * unit * 0.012
                    let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    step == 0 ? spiral.move(to: point) : spiral.addLine(to: point)
                }
                context.stroke(spiral, with: .color(accent.opacity(0.2)), lineWidth: line * 1.5)
            case .stationery:
                var lines = Path()
                stride(from: unit * 0.5, to: size.height, by: unit * 0.42).forEach {
                    lines.move(to: CGPoint(x: 0, y: $0))
                    lines.addLine(to: CGPoint(x: size.width, y: $0))
                }
                context.stroke(lines, with: b, lineWidth: line * 0.6)
                context.stroke(Path(CGRect(x: unit * 0.35, y: 0, width: 0.1, height: size.height)), with: .color(accent.opacity(0.2)), lineWidth: line)
            case .psychicRings:
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
            default:
                break
            }
        }
    }
}
