import SwiftUI

struct IslandShape: Shape {
    var stemWidth: CGFloat
    var stemHeight: CGFloat
    var topRadius: CGFloat
    var bodyTopRadius: CGFloat
    var bottomRadius: CGFloat
    var junctionRadius: CGFloat

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>
    > {
        get {
            AnimatablePair(
                AnimatablePair(stemWidth, stemHeight),
                AnimatablePair(AnimatablePair(topRadius, bodyTopRadius), AnimatablePair(bottomRadius, junctionRadius))
            )
        }
        set {
            stemWidth = newValue.first.first
            stemHeight = newValue.first.second
            topRadius = newValue.second.first.first
            bodyTopRadius = newValue.second.first.second
            bottomRadius = newValue.second.second.first
            junctionRadius = newValue.second.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let stemHeight = min(max(stemHeight, 0), rect.height)
        let stemWidth = min(max(stemWidth, 0), rect.width)
        let bodyTop = rect.minY + stemHeight
        let bodyHeight = rect.maxY - bodyTop
        let hasStem = stemHeight > 0.5 && stemWidth < rect.width - 0.5

        let bottom = min(bottomRadius, bodyHeight / 2, rect.width / 2)
        let stemLeft = rect.midX - stemWidth / 2
        let stemRight = rect.midX + stemWidth / 2

        var path = Path()
        guard hasStem else {
            let top = min(topRadius, bodyHeight / 2, rect.width / 2)
            addBody(to: &path, rect: rect, top: rect.minY, topRadius: top, bottomRadius: bottom)
            return path
        }

        let shoulder = min(junctionRadius, stemHeight, stemLeft - rect.minX)
        let bodyCorner = min(bodyTopRadius, bodyHeight / 2, stemLeft - rect.minX - shoulder)
        let stemTop = min(topRadius, stemHeight, stemWidth / 2)

        path.move(to: CGPoint(x: stemLeft + stemTop, y: rect.minY))
        path.addLine(to: CGPoint(x: stemRight - stemTop, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: stemRight, y: rect.minY + stemTop), control: CGPoint(x: stemRight, y: rect.minY))
        path.addLine(to: CGPoint(x: stemRight, y: bodyTop - shoulder))
        path.addQuadCurve(to: CGPoint(x: stemRight + shoulder, y: bodyTop), control: CGPoint(x: stemRight, y: bodyTop))
        path.addLine(to: CGPoint(x: rect.maxX - bodyCorner, y: bodyTop))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: bodyTop + bodyCorner), control: CGPoint(x: rect.maxX, y: bodyTop))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - bottom, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottom), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: bodyTop + bodyCorner))
        path.addQuadCurve(to: CGPoint(x: rect.minX + bodyCorner, y: bodyTop), control: CGPoint(x: rect.minX, y: bodyTop))
        path.addLine(to: CGPoint(x: stemLeft - shoulder, y: bodyTop))
        path.addQuadCurve(to: CGPoint(x: stemLeft, y: bodyTop - shoulder), control: CGPoint(x: stemLeft, y: bodyTop))
        path.addLine(to: CGPoint(x: stemLeft, y: rect.minY + stemTop))
        path.addQuadCurve(to: CGPoint(x: stemLeft + stemTop, y: rect.minY), control: CGPoint(x: stemLeft, y: rect.minY))
        path.closeSubpath()
        return path
    }

    private func addBody(to path: inout Path, rect: CGRect, top: CGFloat, topRadius: CGFloat, bottomRadius: CGFloat) {
        path.move(to: CGPoint(x: rect.minX + topRadius, y: top))
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: top + topRadius), control: CGPoint(x: rect.maxX, y: top))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: top + topRadius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + topRadius, y: top), control: CGPoint(x: rect.minX, y: top))
        path.closeSubpath()
    }
}
