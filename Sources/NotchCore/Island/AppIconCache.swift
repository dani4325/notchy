import AppKit

@MainActor
enum AppIconCache {
    private static var icons: [String: NSImage] = [:]

    static func icon(forBundleID bundleID: String) -> NSImage? {
        guard !bundleID.isEmpty else { return nil }
        if let cached = icons[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleID] = icon
        return icon
    }
}
