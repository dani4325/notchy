import CoreGraphics
import Foundation
import Testing
@testable import NotchCore

struct IslandLayoutTests {
    static let notches: [CGSize] = [
        CGSize(width: 185, height: 32),
        CGSize(width: 208, height: 37.5),
        CGSize(width: 232, height: 41),
    ]

    static let extremeShapes: [ThemeShape] = [
        .standard,
        ThemeShape(widthRatio: ThemeShape.widthRange.lowerBound, bodyRatio: ThemeShape.bodyRange.lowerBound,
                   bodyTopRadiusRatio: 0, bottomRadiusRatio: 0, junctionRatio: 0),
        ThemeShape(widthRatio: ThemeShape.widthRange.lowerBound, bodyRatio: ThemeShape.bodyRange.upperBound,
                   bodyTopRadiusRatio: ThemeShape.radiusRange.upperBound, bottomRadiusRatio: ThemeShape.radiusRange.upperBound,
                   junctionRatio: ThemeShape.junctionRange.upperBound),
        ThemeShape(widthRatio: ThemeShape.widthRange.upperBound, bodyRatio: ThemeShape.bodyRange.upperBound,
                   bodyTopRadiusRatio: ThemeShape.radiusRange.upperBound, bottomRadiusRatio: ThemeShape.radiusRange.upperBound,
                   junctionRatio: ThemeShape.junctionRange.upperBound),
    ]

    @Test(arguments: notches)
    func stemIsExactlyTheNotch(notch: CGSize) {
        let layout = IslandLayout(notch: notch, shape: .standard)

        #expect(layout.stem == notch)
        #expect(layout.size.height == notch.height + layout.bodyHeight)
    }

    @Test(arguments: notches)
    func sizesScaleWithTheNotch(notch: CGSize) {
        let layout = IslandLayout(notch: notch, shape: .standard)

        #expect(abs(layout.size.width - notch.width * ThemeShape.standard.widthRatio) < 1e-9)
        #expect(abs(layout.bodyHeight - notch.height * ThemeShape.standard.bodyRatio) < 1e-9)
        #expect(abs(layout.titleSize - notch.height * IslandLayout.titleRatio) < 1e-9)
        #expect(abs(layout.padding - notch.height * IslandLayout.paddingRatio) < 1e-9)
    }

    @Test(arguments: notches, extremeShapes)
    func contentFitsInsideTheBodyWithUniformPadding(notch: CGSize, shape: ThemeShape) {
        let layout = IslandLayout(notch: notch, shape: shape)

        #expect(layout.artworkSide > 0)
        #expect(layout.artworkSide + 2 * layout.padding <= layout.bodyHeight + 0.001)
        #expect(layout.textBlockHeight <= layout.artworkSide + 0.001)
        #expect(layout.textWidth >= notch.height * IslandLayout.minimumTextWidthRatio - 0.001)
    }

    @Test(arguments: notches, extremeShapes)
    func radiiNeverExceedTheAvailableSpace(notch: CGSize, shape: ThemeShape) {
        let layout = IslandLayout(notch: notch, shape: shape)
        let shoulder = (layout.size.width - layout.stem.width) / 2

        #expect(layout.junctionRadius + layout.bodyTopRadius <= shoulder + 0.001)
        #expect(layout.bottomRadius <= layout.bodyHeight / 2 + 0.001)
        #expect(layout.junctionRadius <= layout.stem.height + 0.001)
    }

    @Test(arguments: notches, extremeShapes)
    func tShapeHasNoGapsAndLeavesTheMenuBarFree(notch: CGSize, shape: ThemeShape) {
        let layout = IslandLayout(notch: notch, shape: shape)
        let rect = CGRect(origin: .zero, size: layout.size)
        let path = layout.islandShape.path(in: rect)
        let stemLeft = (layout.size.width - notch.width) / 2

        #expect(path.contains(CGPoint(x: rect.midX, y: 0.5)))
        #expect(path.contains(CGPoint(x: stemLeft + 1, y: notch.height - 0.5)))
        #expect(path.contains(CGPoint(x: rect.midX, y: notch.height + 0.5)))
        #expect(path.contains(CGPoint(x: stemLeft - 0.5, y: notch.height + layout.junctionRadius + 1)))
        #expect(path.contains(CGPoint(x: layout.padding, y: notch.height + layout.bodyHeight / 2)))
        #expect(!path.contains(CGPoint(x: 1, y: notch.height / 2)))
        #expect(!path.contains(CGPoint(x: rect.maxX - 1, y: notch.height / 2)))
        #expect(!path.contains(CGPoint(x: stemLeft - layout.junctionRadius - 1, y: 1)))
    }

    @Test func pillUsesTheMenuBarStripAsStem() {
        let layout = IslandLayout(notch: CGSize(width: 184, height: 20), stemHeight: 22, shape: .standard)

        #expect(layout.stem == CGSize(width: 184, height: 22))
        #expect(layout.unit >= IslandLayout.minimumUnit)
    }
}

struct ThemeShapeMigrationTests {
    @Test func legacyPointBasedShapeIsConvertedToRatios() throws {
        let json = #"{"expandedWidth":500,"expandedHeight":170,"bodyTopRadius":18,"bottomRadius":26,"junctionRadius":10}"#

        let shape = try JSONDecoder().decode(ThemeShape.self, from: Data(json.utf8))

        #expect(abs(shape.widthRatio - 500 / IslandLayout.referenceNotch.width) < 0.001)
        #expect(abs(shape.bottomRadiusRatio - 26 / IslandLayout.referenceNotch.height) < 0.001)
        #expect(ThemeShape.bodyRange.contains(shape.bodyRatio))
    }

    @Test func legacyCropCenterBecomesFocusPoint() throws {
        let json = #"{"zoom":2,"centerX":0.3,"centerY":0.7}"#

        let crop = try JSONDecoder().decode(MediaCrop.self, from: Data(json.utf8))

        #expect(crop == MediaCrop(zoom: 2, focusX: 0.3, focusY: 0.7))
    }

    @Test func legacyDimBecomesExtraDarkening() throws {
        let json = #"{"media":{"kind":"image","file":"a.png","crop":{"zoom":1,"focusX":0.5,"focusY":0.5}},"dim":0.1}"#

        let background = try JSONDecoder().decode(ThemeBackground.self, from: Data(json.utf8))

        #expect(background.legibility == 0.1)
    }

    @Test func extraDarkeningIsClampedToItsRange() throws {
        let json = #"{"media":{"kind":"image","file":"a.png","crop":{"zoom":1,"focusX":0.5,"focusY":0.5}},"legibility":3}"#

        let background = try JSONDecoder().decode(ThemeBackground.self, from: Data(json.utf8))

        #expect(background.legibility == ThemeBackground.legibilityRange.upperBound)
    }
}

struct IslandLayoutMarginTests {
    @Test(arguments: IslandLayoutTests.notches)
    func visualMarginsAreEqualOnBothSides(notch: CGSize) {
        let layout = IslandLayout(notch: notch, shape: .standard)
        let lastGlyphInset = (layout.controlDiameter - layout.skipIconSize * IslandLayout.skipGlyphWidthRatio) / 2

        #expect(abs(layout.trailingPadding + lastGlyphInset - layout.padding) < 0.001)
        let used = layout.padding + layout.artworkSide + 2 * layout.columnGap + layout.textWidth + layout.controlsWidth + layout.trailingPadding
        #expect(abs(used - layout.size.width) < 0.001)
    }
}
