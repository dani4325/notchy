import Testing
@testable import NotchCore

struct PowerTransitionTests {
    let unplugged = PowerSnapshot(isExternalPower: false, percent: 64, isCharging: false)
    let plugged = PowerSnapshot(isExternalPower: true, percent: 64, isCharging: true)

    @Test func connectingTheChargerEmitsAConnectedEvent() {
        #expect(PowerTransition.event(from: unplugged, to: plugged) == .connected(percent: 64))
    }

    @Test func disconnectingEmitsADisconnectedEvent() {
        #expect(PowerTransition.event(from: plugged, to: unplugged) == .disconnected(percent: 64))
    }

    @Test func percentageChangesAloneAreIgnored() {
        let charged = PowerSnapshot(isExternalPower: true, percent: 65, isCharging: true)

        #expect(PowerTransition.event(from: plugged, to: charged) == nil)
    }

    @Test func firstReadingNeverAnimates() {
        #expect(PowerTransition.event(from: nil, to: plugged) == nil)
    }

    @Test func desktopsWithoutBatteryNeverAnimate() {
        let noBattery = PowerSnapshot(isExternalPower: true, percent: nil, isCharging: false)

        #expect(PowerTransition.event(from: unplugged, to: noBattery) == nil)
    }
}

struct BatteryLevelEventTests {
    func snapshot(_ percent: Int, external: Bool) -> PowerSnapshot {
        PowerSnapshot(isExternalPower: external, percent: percent, isCharging: external && percent < 100)
    }

    @Test func crossingBelowTheLowThresholdOnBatteryWarnsOnce() {
        #expect(PowerTransition.event(from: snapshot(21, external: false), to: snapshot(20, external: false)) == .low(percent: 20))
        #expect(PowerTransition.event(from: snapshot(20, external: false), to: snapshot(19, external: false)) == nil)
    }

    @Test func reachingFullWhilePluggedInNotifiesOnce() {
        #expect(PowerTransition.event(from: snapshot(99, external: true), to: snapshot(100, external: true)) == .full)
        #expect(PowerTransition.event(from: snapshot(100, external: true), to: snapshot(100, external: true)) == nil)
    }

    @Test func lowBatteryIsNotReportedWhileCharging() {
        #expect(PowerTransition.event(from: snapshot(21, external: true), to: snapshot(20, external: true)) == nil)
    }

    @Test func pluggingInTakesPrecedenceOverLevelEvents() {
        #expect(PowerTransition.event(from: snapshot(21, external: false), to: snapshot(20, external: true)) == .connected(percent: 20))
    }
}

struct PowerSubscriptionPolicyTests {
    @Test func onBatteryOnlyCoarseNotificationsAreUsed() {
        #expect(!PowerSubscriptionPolicy.needsFineGrainedUpdates(PowerSnapshot(isExternalPower: false, percent: 64, isCharging: false)))
    }

    @Test func chargingBelowFullListensForTheFullChargeEvent() {
        #expect(PowerSubscriptionPolicy.needsFineGrainedUpdates(PowerSnapshot(isExternalPower: true, percent: 80, isCharging: true)))
    }

    @Test func fullOrBatterylessMacsStopFineGrainedUpdates() {
        #expect(!PowerSubscriptionPolicy.needsFineGrainedUpdates(PowerSnapshot(isExternalPower: true, percent: 100, isCharging: false)))
        #expect(!PowerSubscriptionPolicy.needsFineGrainedUpdates(PowerSnapshot(isExternalPower: true, percent: nil, isCharging: false)))
    }

    @Test func systemLowBatteryWarningBecomesALowEventOnlyOnBattery() {
        #expect(PowerSubscriptionPolicy.lowBatteryEvent(PowerSnapshot(isExternalPower: false, percent: 18, isCharging: false)) == .low(percent: 18))
        #expect(PowerSubscriptionPolicy.lowBatteryEvent(PowerSnapshot(isExternalPower: true, percent: 18, isCharging: true)) == nil)
    }
}
