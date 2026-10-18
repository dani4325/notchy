import CoreGraphics
import Testing
@testable import NotchCore

struct MediaCropTests {
    @Test func wideMediaIsCroppedHorizontallyToTargetAspect() {
        let rect = MediaCrop.standard.rect(mediaAspect: 4, targetAspect: 2)

        #expect(rect == CGRect(x: 0.25, y: 0, width: 0.5, height: 1))
    }

    @Test func tallMediaIsCroppedVertically() {
        let rect = MediaCrop.standard.rect(mediaAspect: 1, targetAspect: 2)

        #expect(rect == CGRect(x: 0, y: 0.25, width: 1, height: 0.5))
    }

    @Test func zoomShrinksTheWindowAroundTheCenter() {
        let crop = MediaCrop(zoom: 2, focusX: 0.5, focusY: 0.5)

        #expect(crop.rect(mediaAspect: 2, targetAspect: 2) == CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
    }

    @Test func focusNearTheEdgeIsClampedSoTheWindowStaysInsideTheMedia() {
        let crop = MediaCrop(zoom: 2, focusX: 0, focusY: 1)

        #expect(crop.rect(mediaAspect: 2, targetAspect: 2) == CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5))
    }

    @Test func zoomIsClampedToAllowedRange() {
        #expect(MediaCrop(zoom: 0.2, focusX: 0.5, focusY: 0.5).sanitized().zoom == MediaCrop.zoomRange.lowerBound)
        #expect(MediaCrop(zoom: 50, focusX: 2, focusY: -1).sanitized() == MediaCrop(zoom: MediaCrop.zoomRange.upperBound, focusX: 1, focusY: 0))
    }
}

struct MediaCropFocusTests {
    @Test func windowIsCenteredOnTheFocusPointWhenThereIsRoom() {
        let crop = MediaCrop(zoom: 1, focusX: 0.5, focusY: 0.3)

        let rect = crop.rect(mediaAspect: 1, targetAspect: 3)

        #expect(abs(rect.midY - 0.3) < 0.0001)
    }

    @Test func draggingMovesTheFocusOppositeToTheFingerAndStaysReachable() {
        let crop = MediaCrop.standard

        let moved = crop.dragged(by: CGSize(width: 100, height: 0), displayedSize: CGSize(width: 400, height: 100), mediaAspect: 8)

        #expect(moved.focusX < 0.5)
        let window = moved.rect(mediaAspect: 8, targetAspect: 4)
        #expect(abs(moved.focusX - window.midX) < 0.0001)
    }
}
