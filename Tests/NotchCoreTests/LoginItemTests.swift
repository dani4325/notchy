import ServiceManagement
import Testing
@testable import NotchCore

struct LoginItemTests {
    @Test func mapsEveryServiceStatus() {
        #expect(LoginItemState(.enabled) == .enabled)
        #expect(LoginItemState(.notRegistered) == .disabled)
        #expect(LoginItemState(.requiresApproval) == .needsApproval)
        #expect(LoginItemState(.notFound) == .unavailable)
    }

    @Test func onlyEnabledCountsAsOn() {
        #expect(LoginItemState.enabled.isOn)
        #expect(!LoginItemState.needsApproval.isOn)
        #expect(!LoginItemState.disabled.isOn)
    }
}
