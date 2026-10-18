import SwiftUI
import Testing
@testable import NotchCore

struct IslandShapeTests {
    let rect = CGRect(x: 0, y: 0, width: 500, height: 170)

    func tShape() -> IslandShape {
        IslandShape(stemWidth: 208, stemHeight: 38, topRadius: 0, bodyTopRadius: 18, bottomRadius: 26, junctionRadius: 10)
    }

    @Test func stemCoversTheNotchColumnInTheMenuBarStrip() {
        let path = tShape().path(in: rect)

        #expect(path.contains(CGPoint(x: 250, y: 2)))
        #expect(path.contains(CGPoint(x: 150, y: 30)))
    }

    @Test func menuBarStripBesideTheStemIsEmpty() {
        let path = tShape().path(in: rect)

        #expect(!path.contains(CGPoint(x: 20, y: 10)))
        #expect(!path.contains(CGPoint(x: 480, y: 20)))
        #expect(!path.contains(CGPoint(x: 140, y: 5)))
    }

    @Test func bodyFillsTheWidthBelowTheStrip() {
        let path = tShape().path(in: rect)

        #expect(path.contains(CGPoint(x: 30, y: 100)))
        #expect(path.contains(CGPoint(x: 470, y: 100)))
    }

    @Test func zeroStemIsAPlainRoundedBody() {
        let shape = IslandShape(stemWidth: 208, stemHeight: 0, topRadius: 0, bodyTopRadius: 0, bottomRadius: 10, junctionRadius: 0)
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 208, height: 38))

        #expect(path.contains(CGPoint(x: 1, y: 1)))
        #expect(path.contains(CGPoint(x: 207, y: 1)))
        #expect(!path.contains(CGPoint(x: 0.5, y: 37.5)))
    }
}
