import Observation

public enum SettingsSection: String, CaseIterable, Sendable {
    case themes
    case general

    var title: String {
        switch self {
        case .themes: String(localized: "Temas")
        case .general: String(localized: "General")
        }
    }
}

@MainActor
@Observable
public final class SettingsRouter {
    public var section: SettingsSection = .themes

    public init() {}
}
