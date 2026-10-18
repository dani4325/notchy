import SwiftUI

enum NixieStyle {
    static let fontFamily = "Nixie One"
    static let tubeAspect: CGFloat = 0.62
    static let tubeSpacingRatio: CGFloat = 0.06
    static let digitScale: CGFloat = 0.78
    static let ghostOpacity = 0.09
    static let meshOpacity = 0.12
    static let separatorWidthRatio: CGFloat = 0.28
}

enum NixieSymbol: Equatable, Hashable {
    case digit(Character)
    case separator
    case sign
    case dot
}

enum NixieReadout {
    static func symbols(_ text: String) -> [NixieSymbol] {
        text.compactMap { character in
            switch character {
            case "0"..."9": .digit(character)
            case ":": .separator
            case "-": .sign
            case ".": .dot
            default: nil
            }
        }
    }
}

struct NixieReadoutView: View {
    let text: String
    let height: CGFloat
    let glow: Color

    var body: some View {
        HStack(spacing: height * NixieStyle.tubeSpacingRatio) {
            ForEach(Array(NixieReadout.symbols(text).enumerated()), id: \.offset) { _, symbol in
                switch symbol {
                case .digit(let digit):
                    NixieTube(digit: digit, height: height, glow: glow)
                case .separator:
                    NixieSeparator(height: height, glow: glow)
                case .dot:
                    Circle()
                        .fill(Color(red: 1, green: 0.86, blue: 0.62))
                        .frame(width: height * 0.08, height: height * 0.08)
                        .shadow(color: glow, radius: height * 0.08)
                        .frame(width: height * 0.16, height: height, alignment: .bottom)
                        .padding(.bottom, height * 0.12)
                case .sign:
                    Capsule()
                        .fill(glow)
                        .frame(width: height * 0.22, height: max(height * 0.05, 1))
                        .shadow(color: glow.opacity(0.9), radius: height * 0.08)
                        .frame(width: height * NixieStyle.separatorWidthRatio, height: height)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

private struct NixieTube: View {
    let digit: Character
    let height: CGFloat
    let glow: Color

    var body: some View {
        let width = height * NixieStyle.tubeAspect
        let glass = RoundedRectangle(cornerRadius: width * 0.42, style: .continuous)
        let digitFont = Font.custom(NixieStyle.fontFamily, size: height * NixieStyle.digitScale)

        ZStack {
            glass.fill(LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0.02), glow.opacity(0.06)],
                startPoint: .top, endPoint: .bottom
            ))
            NixieMesh()
                .stroke(glow.opacity(NixieStyle.meshOpacity), lineWidth: 0.5)
                .padding(width * 0.12)
            ForEach(["8", "0", "3"], id: \.self) { ghost in
                Text(ghost).font(digitFont).foregroundStyle(glow.opacity(NixieStyle.ghostOpacity))
            }
            Text(String(digit))
                .font(digitFont)
                .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.62))
                .shadow(color: glow, radius: height * 0.06)
                .shadow(color: glow.opacity(0.8), radius: height * 0.16)
            glass.strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
        }
        .frame(width: width, height: height)
    }
}

private struct NixieSeparator: View {
    let height: CGFloat
    let glow: Color

    var body: some View {
        VStack(spacing: height * 0.22) {
            ForEach(0..<2, id: \.self) { _ in
                Circle()
                    .fill(Color(red: 1, green: 0.86, blue: 0.62))
                    .frame(width: height * 0.09, height: height * 0.09)
                    .shadow(color: glow, radius: height * 0.08)
            }
        }
        .frame(width: height * NixieStyle.separatorWidthRatio, height: height)
    }
}

private struct NixieMesh: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = max(rect.width / 4, 2)
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.maxY))
            x += step
        }
        return path.intersection(Path(roundedRect: rect, cornerRadius: rect.width * 0.4))
    }
}
