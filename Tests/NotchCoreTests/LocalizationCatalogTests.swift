import Foundation
import Testing

struct LocalizationCatalogTests {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Localization")

    static func entries(_ file: String) throws -> [String: [String: String]] {
        let data = try Data(contentsOf: directory.appendingPathComponent(file))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: [String: Any]])
        return strings.mapValues { entry in
            let localizations = entry["localizations"] as? [String: [String: [String: String]]] ?? [:]
            return localizations.compactMapValues { $0["stringUnit"]?["value"] }
        }
    }

    static func placeholders(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(@|lld|d|f)")
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { (text as NSString).substring(with: $0.range) }
    }

    @Test(arguments: ["Localizable.xcstrings", "InfoPlist.xcstrings"])
    func everyEntryHasSpanishAndEnglishWithMatchingPlaceholders(file: String) throws {
        let entries = try Self.entries(file)

        #expect(!entries.isEmpty)
        for (key, values) in entries {
            let spanish = try #require(values["es"], "falta es en \(key)")
            let english = try #require(values["en"], "falta en en \(key)")
            #expect(!spanish.isEmpty && !english.isEmpty, "\(key)")
            #expect(Self.placeholders(spanish) == Self.placeholders(english), "\(key)")
        }
    }
}
