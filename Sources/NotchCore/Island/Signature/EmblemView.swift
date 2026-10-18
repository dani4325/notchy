import SwiftUI

struct EmblemView: View {
    let emblem: ThemeEmblem
    let size: CGFloat
    let appearance: ThemeAppearance

    var body: some View {
        Group {
            switch emblem {
            case .nixieTube:
                NixieReadoutView(text: "1", height: size * 0.82, glow: appearance.secondary)
            case .menacingGlyph:
                Text("ゴ")
                    .font(.custom("Dela Gothic One", size: size * 0.7))
                    .foregroundStyle(LinearGradient(colors: [appearance.secondary, appearance.accent], startPoint: .top, endPoint: .bottom))
            case .percentMeter:
                PercentMeter(size: size, appearance: appearance)
            default:
                Canvas { context, canvas in
                    EmblemPainter(context: context, side: min(canvas.width, canvas.height), appearance: appearance).draw(emblem)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct PercentMeter: View {
    let size: CGFloat
    let appearance: ThemeAppearance

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(appearance.text.opacity(0.18), style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
                .rotationEffect(.degrees(90))
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(AngularGradient(colors: [appearance.accent, appearance.secondary, appearance.accent], center: .center),
                        style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
                .rotationEffect(.degrees(90))
            Text("100%")
                .font(.custom("Dela Gothic One", size: size * 0.2))
                .foregroundStyle(appearance.text)
        }
        .padding(size * 0.1)
    }
}

private struct EmblemPainter {
    let context: GraphicsContext
    let side: CGFloat
    let appearance: ThemeAppearance

    private var accent: GraphicsContext.Shading { .color(appearance.accent) }
    private var secondary: GraphicsContext.Shading { .color(appearance.secondary) }
    private var ink: GraphicsContext.Shading { .color(appearance.text.opacity(0.85)) }
    private var line: CGFloat { side * 0.045 }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * side, y: y * side) }
    private func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * side, y: y * side, width: w * side, height: h * side) }

    private func polygon(_ points: [CGPoint]) -> Path {
        Path { path in
            path.addLines(points)
            path.closeSubpath()
        }
    }

    func draw(_ emblem: ThemeEmblem) {
        switch emblem {
        case .crossedBlades:
            for flip in [false, true] {
                var blade = context
                blade.translateBy(x: side / 2, y: side / 2)
                blade.rotate(by: .degrees(flip ? -38 : 38))
                blade.fill(polygon([p(-0.03, -0.42), p(0.03, -0.42), p(0.03, 0.18), p(-0.03, 0.18)].map { CGPoint(x: $0.x, y: $0.y) }), with: .color(appearance.text.opacity(0.9)))
                blade.fill(Path(r(-0.09, 0.18, 0.18, 0.04)), with: accent)
                blade.fill(Path(r(-0.035, 0.22, 0.07, 0.18)), with: secondary)
            }
            for column in 0..<4 {
                context.stroke(Path(r(0.1 + CGFloat(column) * 0.2, 0.8, 0.2, 0.1)), with: .color(appearance.accent.opacity(0.6)), lineWidth: line * 0.6)
            }
        case .katana:
            var blade = context
            blade.translateBy(x: side / 2, y: side / 2)
            blade.rotate(by: .degrees(-40))
            var edge = Path()
            edge.move(to: p(-0.025, -0.44))
            edge.addQuadCurve(to: p(0.03, 0.16), control: p(0.05, -0.15))
            edge.addLine(to: p(-0.025, 0.16))
            edge.closeSubpath()
            blade.fill(edge, with: .color(appearance.text.opacity(0.92)))
            blade.fill(Path(ellipseIn: r(-0.09, 0.15, 0.18, 0.05)), with: accent)
            blade.fill(Path(r(-0.03, 0.2, 0.06, 0.24)), with: .color(.black.opacity(0.85)))
            for wrap in 0..<4 {
                blade.stroke(Path { $0.move(to: p(-0.03, 0.22 + CGFloat(wrap) * 0.055)); $0.addLine(to: p(0.03, 0.25 + CGFloat(wrap) * 0.055)) }, with: secondary, lineWidth: line * 0.5)
            }
        case .astrolabe:
            for (index, radius) in [0.4, 0.3, 0.18].enumerated() {
                context.stroke(Path(ellipseIn: r(0.5 - radius, 0.5 - radius, radius * 2, radius * 2)), with: index == 0 ? accent : secondary, lineWidth: line * (index == 0 ? 1 : 0.6))
            }
            for tick in 0..<12 {
                let angle = Double(tick) * .pi / 6
                context.stroke(Path { $0.move(to: p(0.5 + cos(angle) * 0.34, 0.5 + sin(angle) * 0.34)); $0.addLine(to: p(0.5 + cos(angle) * 0.4, 0.5 + sin(angle) * 0.4)) }, with: accent, lineWidth: line * 0.5)
            }
            context.stroke(Path { $0.move(to: p(0.22, 0.72)); $0.addLine(to: p(0.78, 0.28)) }, with: ink, lineWidth: line * 0.8)
            context.fill(polygon([p(0.5, 0.08), p(0.54, 0.02), p(0.58, 0.08), p(0.54, 0.12)]), with: accent)
        case .coffeeCup:
            context.fill(Path(ellipseIn: r(0.14, 0.72, 0.72, 0.12)), with: .color(appearance.text.opacity(0.35)))
            context.fill(polygon([p(0.24, 0.4), p(0.68, 0.4), p(0.62, 0.76), p(0.3, 0.76)]), with: .color(appearance.text.opacity(0.9)))
            context.stroke(Path(ellipseIn: r(0.62, 0.46, 0.18, 0.16)), with: .color(appearance.text.opacity(0.9)), lineWidth: line)
            context.fill(Path(ellipseIn: r(0.25, 0.37, 0.42, 0.07)), with: .color(Color(red: 0.25, green: 0.13, blue: 0.08)))
            for x in [0.36, 0.48, 0.58] {
                context.stroke(Path { $0.move(to: p(x, 0.32)); $0.addCurve(to: p(x, 0.1), control1: p(x - 0.06, 0.25), control2: p(x + 0.06, 0.17)) }, with: accent, lineWidth: line * 0.7)
            }
        case .tacticalMap:
            context.stroke(Path(r(0.12, 0.12, 0.76, 0.76)), with: secondary, lineWidth: line * 0.7)
            for i in 1..<4 {
                let offset = 0.12 + CGFloat(i) * 0.19
                context.stroke(Path { $0.move(to: p(offset, 0.12)); $0.addLine(to: p(offset, 0.88)); $0.move(to: p(0.12, offset)); $0.addLine(to: p(0.88, offset)) }, with: .color(appearance.secondary.opacity(0.4)), lineWidth: line * 0.4)
            }
            for spot in [(0.3, 0.32), (0.62, 0.5), (0.45, 0.72)] {
                context.fill(polygon([p(spot.0, spot.1 - 0.06), p(spot.0 + 0.055, spot.1 + 0.04), p(spot.0 - 0.055, spot.1 + 0.04)]), with: accent)
            }
            context.fill(Path(ellipseIn: r(0.7, 0.2, 0.08, 0.08)), with: .color(Color.red.opacity(0.85)))
        case .grimoire:
            context.fill(Path(roundedRect: r(0.2, 0.12, 0.6, 0.76), cornerRadius: side * 0.05), with: .color(Color(red: 0.12, green: 0.1, blue: 0.08)))
            context.stroke(Path(roundedRect: r(0.2, 0.12, 0.6, 0.76), cornerRadius: side * 0.05), with: secondary, lineWidth: line * 0.7)
            context.fill(Path(r(0.22, 0.14, 0.05, 0.72)), with: .color(appearance.secondary.opacity(0.5)))
            for quarter in 0..<4 {
                let angle = Double(quarter) * .pi / 2 + .pi / 4
                context.fill(Path(ellipseIn: r(0.53 + cos(angle) * 0.075 - 0.08, 0.48 + sin(angle) * 0.075 - 0.08, 0.16, 0.16)), with: accent)
            }
            context.stroke(Path { $0.move(to: p(0.53, 0.5)); $0.addQuadCurve(to: p(0.6, 0.68), control: p(0.53, 0.62)) }, with: accent, lineWidth: line * 0.6)
        case .sealedFinger:
            var finger = context
            finger.translateBy(x: side / 2, y: side / 2)
            finger.rotate(by: .degrees(-20))
            finger.fill(Path(roundedRect: r(-0.1, -0.4, 0.2, 0.78), cornerRadius: side * 0.1), with: .color(Color(red: 0.55, green: 0.42, blue: 0.4)))
            for band in 0..<5 {
                finger.stroke(Path { $0.move(to: p(-0.1, -0.22 + CGFloat(band) * 0.12)); $0.addLine(to: p(0.1, -0.18 + CGFloat(band) * 0.12)) }, with: .color(appearance.text.opacity(0.8)), lineWidth: line * 0.9)
            }
            finger.fill(Path(r(-0.17, -0.05, 0.34, 0.16)), with: .color(Color(red: 0.95, green: 0.9, blue: 0.75)))
            finger.stroke(Path { $0.move(to: p(-0.12, 0.03)); $0.addLine(to: p(0.12, 0.03)) }, with: .color(Color.red.opacity(0.8)), lineWidth: line * 0.7)
        case .chainsaw:
            context.fill(Path(roundedRect: r(0.08, 0.38, 0.38, 0.3), cornerRadius: side * 0.06), with: accent)
            context.stroke(Path { $0.move(to: p(0.16, 0.38)); $0.addQuadCurve(to: p(0.38, 0.38), control: p(0.27, 0.22)) }, with: .color(appearance.text.opacity(0.85)), lineWidth: line)
            context.fill(Path(roundedRect: r(0.44, 0.45, 0.48, 0.16), cornerRadius: side * 0.08), with: .color(appearance.text.opacity(0.8)))
            var x: CGFloat = 0.46
            while x < 0.9 {
                context.fill(polygon([p(x, 0.45), p(x + 0.025, 0.4), p(x + 0.05, 0.45)]), with: .color(appearance.text.opacity(0.8)))
                context.fill(polygon([p(x, 0.61), p(x + 0.025, 0.66), p(x + 0.05, 0.61)]), with: .color(appearance.text.opacity(0.8)))
                x += 0.055
            }
        case .pocketWatch:
            context.stroke(Path { $0.move(to: p(0.5, 0.2)); $0.addCurve(to: p(0.9, 0.1), control1: p(0.6, 0.02), control2: p(0.8, 0.25)) }, with: secondary, lineWidth: line * 0.7)
            context.fill(Path(r(0.46, 0.14, 0.08, 0.08)), with: accent)
            context.fill(Path(ellipseIn: r(0.16, 0.22, 0.68, 0.68)), with: accent)
            context.fill(Path(ellipseIn: r(0.21, 0.27, 0.58, 0.58)), with: .color(Color(red: 0.96, green: 0.92, blue: 0.82)))
            context.stroke(Path { $0.move(to: p(0.5, 0.56)); $0.addLine(to: p(0.5, 0.36)); $0.move(to: p(0.5, 0.56)); $0.addLine(to: p(0.64, 0.62)) }, with: .color(.black), lineWidth: line * 0.7)
        case .staffAndFlowers:
            context.stroke(Path { $0.move(to: p(0.32, 0.92)); $0.addLine(to: p(0.42, 0.18)) }, with: .color(Color(red: 0.6, green: 0.45, blue: 0.3)), lineWidth: line)
            context.stroke(Path(ellipseIn: r(0.32, 0.04, 0.2, 0.2)), with: secondary, lineWidth: line * 0.8)
            context.fill(Path(ellipseIn: r(0.38, 0.1, 0.08, 0.08)), with: accent)
            for spot in [(0.66, 0.6), (0.78, 0.72), (0.6, 0.78), (0.74, 0.5)] {
                context.stroke(Path { $0.move(to: p(spot.0, spot.1)); $0.addLine(to: p(0.68, 0.92)) }, with: .color(Color.green.opacity(0.6)), lineWidth: line * 0.4)
                for leaf in 0..<5 {
                    let angle = Double(leaf) * 2 * .pi / 5
                    context.fill(Path(ellipseIn: r(spot.0 + cos(angle) * 0.035 - 0.03, spot.1 + sin(angle) * 0.035 - 0.03, 0.06, 0.06)), with: accent)
                }
            }
        case .strawHat:
            let straw = Color(red: 0.93, green: 0.78, blue: 0.4)
            context.fill(Path(ellipseIn: r(0.06, 0.5, 0.88, 0.24)), with: .color(straw))
            context.fill(Path { $0.addArc(center: p(0.5, 0.56), radius: side * 0.24, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false); $0.closeSubpath() }, with: .color(straw))
            context.fill(Path(r(0.26, 0.47, 0.48, 0.08)), with: .color(Color(red: 0.82, green: 0.12, blue: 0.12)))
            context.stroke(Path(ellipseIn: r(0.06, 0.5, 0.88, 0.24)), with: .color(Color(red: 0.6, green: 0.45, blue: 0.2)), lineWidth: line * 0.4)
        case .kunai:
            var kunai = context
            kunai.translateBy(x: side / 2, y: side / 2)
            kunai.rotate(by: .degrees(-45))
            kunai.fill(polygon([p(0, -0.44), p(0.1, -0.12), p(0, -0.06), p(-0.1, -0.12)]), with: .color(appearance.text.opacity(0.9)))
            kunai.fill(Path(r(-0.025, -0.06, 0.05, 0.32)), with: .color(Color(red: 0.15, green: 0.15, blue: 0.18)))
            for wrap in 0..<5 {
                kunai.stroke(Path { $0.move(to: p(-0.03, -0.03 + CGFloat(wrap) * 0.06)); $0.addLine(to: p(0.03, 0 + CGFloat(wrap) * 0.06)) }, with: secondary, lineWidth: line * 0.5)
            }
            kunai.stroke(Path(ellipseIn: r(-0.07, 0.26, 0.14, 0.14)), with: .color(appearance.text.opacity(0.9)), lineWidth: line * 0.8)
        case .typewriter:
            context.fill(Path(r(0.3, 0.1, 0.4, 0.3)), with: .color(Color(red: 0.97, green: 0.94, blue: 0.86)))
            for row in 0..<3 {
                context.stroke(Path { $0.move(to: p(0.35, 0.18 + CGFloat(row) * 0.06)); $0.addLine(to: p(0.62, 0.18 + CGFloat(row) * 0.06)) }, with: .color(.gray), lineWidth: line * 0.3)
            }
            context.fill(Path(roundedRect: r(0.12, 0.38, 0.76, 0.12), cornerRadius: side * 0.04), with: .color(Color(red: 0.2, green: 0.2, blue: 0.24)))
            context.fill(polygon([p(0.16, 0.5), p(0.84, 0.5), p(0.92, 0.84), p(0.08, 0.84)]), with: .color(Color(red: 0.16, green: 0.16, blue: 0.2)))
            for row in 0..<3 {
                for key in 0..<(7 - row) {
                    let x = 0.2 + CGFloat(key) * 0.1 + CGFloat(row) * 0.05
                    context.fill(Path(ellipseIn: r(x, 0.56 + CGFloat(row) * 0.09, 0.06, 0.06)), with: accent)
                }
            }
        case .nixieTube, .menacingGlyph, .percentMeter:
            break
        }
    }
}
