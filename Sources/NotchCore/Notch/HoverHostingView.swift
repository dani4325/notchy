import AppKit
import SwiftUI

final class HoverHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChange: ((Bool) -> Void)?

    private var screenRegions: [CGRect] = []
    private var trackingAreasInUse: [NSTrackingArea] = []
    private var areasContainingMouse: Set<ObjectIdentifier> = []
    private var isInside = false

    required init(rootView: Content) {
        super.init(rootView: rootView)
        sizingOptions = []
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setHoverRegions(_ regions: [CGRect]) {
        screenRegions = regions
        rebuildTrackingAreas()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        rebuildTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        guard let area = event.trackingArea else { return }
        areasContainingMouse.insert(ObjectIdentifier(area))
        reportIfChanged()
    }

    override func mouseExited(with event: NSEvent) {
        guard let area = event.trackingArea else { return }
        areasContainingMouse.remove(ObjectIdentifier(area))
        reportIfChanged()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func rebuildTrackingAreas() {
        trackingAreasInUse.forEach(removeTrackingArea)
        guard let window else {
            trackingAreasInUse = []
            return
        }
        let mouse = NSEvent.mouseLocation
        trackingAreasInUse = screenRegions.map { region in
            let local = convert(window.convertFromScreen(region), from: nil)
            let area = NSTrackingArea(rect: local, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
            addTrackingArea(area)
            return area
        }
        areasContainingMouse = Set(
            zip(screenRegions, trackingAreasInUse)
                .filter { region, _ in region.contains(mouse) }
                .map { ObjectIdentifier($0.1) }
        )
        reportIfChanged()
    }

    private func reportIfChanged() {
        let inside = !areasContainingMouse.isEmpty
        guard inside != isInside else { return }
        isInside = inside
        onHoverChange?(inside)
    }
}
