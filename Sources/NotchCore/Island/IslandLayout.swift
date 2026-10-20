import CoreGraphics

struct IslandLayout: Equatable {
    static let referenceNotch = CGSize(width: 208, height: 37.5)
    static let minimumUnit: CGFloat = 24

    static let paddingRatio: CGFloat = 0.55
    static let columnGapRatio: CGFloat = 0.42
    static let maxArtworkRatio: CGFloat = 2.6
    static let artworkCornerRatio: CGFloat = 0.19
    static let titleRatio: CGFloat = 0.44
    static let subtitleRatio: CGFloat = 0.36
    static let labelRatio: CGFloat = 0.25
    static let timeRatio: CGFloat = 0.27
    static let lineHeightFactor: CGFloat = 1.3
    static let textSpacingRatio: CGFloat = 0.08
    static let progressRatio: CGFloat = 0.1
    static let progressGapRatio: CGFloat = 0.18
    static let controlRatio: CGFloat = 1.0
    static let controlSpacingRatio: CGFloat = 0.12
    static let playIconRatio: CGFloat = 0.58
    static let skipIconRatio: CGFloat = 0.4
    static let skipGlyphWidthRatio: CGFloat = 1.35
    static let topBlendWidthRatio: CGFloat = 1.6
    static let minimumTextWidthRatio: CGFloat = 3
    static let topBlendRatio: CGFloat = 0.7
    static let maxJunctionShare: CGFloat = 0.5

    let stem: CGSize
    let unit: CGFloat
    let bodyHeight: CGFloat
    let size: CGSize
    private let shape: ThemeShape

    init(notch: CGSize, stemHeight: CGFloat? = nil, shape: ThemeShape) {
        let safeShape = shape.sanitized()
        let stem = CGSize(width: notch.width, height: stemHeight ?? notch.height)
        let unit = max(stem.height, Self.minimumUnit)
        let bodyHeight = unit * safeShape.bodyRatio
        self.stem = stem
        self.unit = unit
        self.bodyHeight = bodyHeight
        self.shape = safeShape
        size = CGSize(width: notch.width * safeShape.widthRatio, height: stem.height + bodyHeight)
    }

    var padding: CGFloat { unit * Self.paddingRatio }
    var columnGap: CGFloat { unit * Self.columnGapRatio }
    var artworkSide: CGFloat { min(bodyHeight - 2 * padding, unit * Self.maxArtworkRatio) }
    var artworkCorner: CGFloat { artworkSide * Self.artworkCornerRatio }

    static let minimumTextSize: CGFloat = 10

    var titleSize: CGFloat { max(unit * Self.titleRatio, Self.minimumTextSize) }
    var subtitleSize: CGFloat { max(unit * Self.subtitleRatio, Self.minimumTextSize) }
    var labelSize: CGFloat { unit * Self.labelRatio }
    var timeSize: CGFloat { max(unit * Self.timeRatio, Self.minimumTextSize) }
    var textSpacing: CGFloat { unit * Self.textSpacingRatio }
    var progressHeight: CGFloat { unit * Self.progressRatio }
    var progressGap: CGFloat { unit * Self.progressGapRatio }

    var controlDiameter: CGFloat { unit * Self.controlRatio }
    var controlSpacing: CGFloat { unit * Self.controlSpacingRatio }
    var playIconSize: CGFloat { unit * Self.playIconRatio }
    var skipIconSize: CGFloat { unit * Self.skipIconRatio }
    var controlsWidth: CGFloat { 3 * controlDiameter + 2 * controlSpacing }

    var trailingPadding: CGFloat {
        let glyphInset = (controlDiameter - skipIconSize * Self.skipGlyphWidthRatio) / 2
        return max(padding - glyphInset, 0)
    }

    var textWidth: CGFloat {
        size.width - padding - trailingPadding - artworkSide - 2 * columnGap - controlsWidth
    }

    var textBlockHeight: CGFloat {
        Self.lineHeightFactor * (labelSize + titleSize + subtitleSize + timeSize)
            + 3 * textSpacing + progressHeight + progressGap
    }

    var nixieHeight: CGFloat {
        let line = timeSize * Self.lineHeightFactor
        return min(line * 1.4, line + max(artworkSide - textBlockHeight, 0))
    }

    var topBlendHeight: CGFloat { unit * Self.topBlendRatio }
    var topBlendWidth: CGFloat { stem.width * Self.topBlendWidthRatio }

    private var shoulder: CGFloat { (size.width - stem.width) / 2 }

    var junctionRadius: CGFloat {
        min(unit * shape.junctionRatio, stem.height, shoulder * Self.maxJunctionShare)
    }

    var bodyTopRadius: CGFloat {
        min(unit * shape.bodyTopRadiusRatio, shoulder - junctionRadius, bodyHeight / 2)
    }

    var bottomRadius: CGFloat {
        min(unit * shape.bottomRadiusRatio, bodyHeight / 2, size.width / 2)
    }

    var bodyRect: CGRect {
        CGRect(x: 0, y: stem.height, width: size.width, height: bodyHeight)
    }

    var islandShape: IslandShape {
        IslandShape(
            stemWidth: stem.width,
            stemHeight: stem.height,
            topRadius: 0,
            bodyTopRadius: bodyTopRadius,
            bottomRadius: bottomRadius,
            junctionRadius: junctionRadius
        )
    }
}
