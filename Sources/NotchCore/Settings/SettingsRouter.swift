import Observation

public enum SettingsSection: String, CaseIterable, Sendable {
    case themes
    case general

    var title: String {
        switch self {
        case .themes: "Temas"
        case .general: "General"
        }
    }
}

@MainActor
@Observable
public final class SettingsRouter {
    public var section: SettingsSection = .themes

    public init() {}
}
