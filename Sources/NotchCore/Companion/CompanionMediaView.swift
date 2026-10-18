import AppKit
import SwiftUI

struct CompanionMediaView: NSViewRepresentable {
    let image: NSImage
    let isAnimating: Bool

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageFrameStyle = .none
        view.isEditable = false
        view.setAccessibilityElement(false)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        if view.image !== image {
            view.image = image
        }
        if view.animates != isAnimating {
            view.animates = isAnimating
        }
    }
}
