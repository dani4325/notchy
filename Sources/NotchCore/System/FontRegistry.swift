import CoreText
import Foundation
import os

public enum FontRegistry {
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "fonts")

    public static var bundledFontsDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Fonts", isDirectory: true)
    }

    public static func register(directory: URL) {
        let fonts = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in fonts where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let code = error.map { CFErrorGetCode($0.takeRetainedValue()) } ?? 0
                if code != CTFontManagerError.alreadyRegistered.rawValue {
                    logger.error("font registration failed: \(url.lastPathComponent, privacy: .public) (\(code))")
                }
            }
        }
    }
}
