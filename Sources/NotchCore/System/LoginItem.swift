import Observation
import os
import ServiceManagement

public enum LoginItemState: Equatable, Sendable {
    case enabled
    case disabled
    case needsApproval
    case unavailable

    init(_ status: SMAppService.Status) {
        switch status {
        case .enabled: self = .enabled
        case .requiresApproval: self = .needsApproval
        case .notFound: self = .unavailable
        default: self = .disabled
        }
    }

    public var isOn: Bool { self == .enabled }
}

@MainActor
@Observable
public final class LoginItem {
    public private(set) var state = LoginItemState(SMAppService.mainApp.status)
    public private(set) var message: String?

    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "login")

    public init() {}

    public func refresh() {
        state = LoginItemState(SMAppService.mainApp.status)
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            message = nil
        } catch {
            Self.logger.error("login item change failed: \(error.localizedDescription, privacy: .public)")
            message = enabled
                ? String(localized: "macOS no ha permitido activar el arranque. Mueve Notchy a Aplicaciones y vuelve a intentarlo.")
                : String(localized: "No se ha podido desactivar el arranque.")
        }
        refresh()
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
