import Foundation
import IOKit.ps
import notify
import os

struct PowerSnapshot: Equatable, Sendable {
    let isExternalPower: Bool
    let percent: Int?
    let isCharging: Bool
}

public enum PowerEvent: Equatable, Sendable {
    case connected(percent: Int)
    case disconnected(percent: Int)
    case low(percent: Int)
    case full

    var percent: Int {
        switch self {
        case .connected(let percent), .disconnected(let percent), .low(let percent): percent
        case .full: 100
        }
    }

    var isConnected: Bool {
        switch self {
        case .connected, .full: true
        case .disconnected, .low: false
        }
    }
}

enum PowerTransition {
    static let lowThreshold = 20
    static let fullThreshold = 100

    static func event(from previous: PowerSnapshot?, to current: PowerSnapshot) -> PowerEvent? {
        guard let previous, let percent = current.percent else { return nil }
        if previous.isExternalPower != current.isExternalPower {
            return current.isExternalPower ? .connected(percent: percent) : .disconnected(percent: percent)
        }
        let before = previous.percent ?? percent
        if !current.isExternalPower, before > lowThreshold, percent <= lowThreshold {
            return .low(percent: percent)
        }
        if current.isExternalPower, before < fullThreshold, percent >= fullThreshold {
            return .full
        }
        return nil
    }
}

enum PowerSubscriptionPolicy {
    static func needsFineGrainedUpdates(_ snapshot: PowerSnapshot) -> Bool {
        guard snapshot.isExternalPower, let percent = snapshot.percent else { return false }
        return percent < PowerTransition.fullThreshold
    }

    static func lowBatteryEvent(_ snapshot: PowerSnapshot) -> PowerEvent? {
        guard !snapshot.isExternalPower, let percent = snapshot.percent else { return nil }
        return .low(percent: percent)
    }
}

@MainActor
public final class PowerMonitor {
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "power")

    public var onEvent: ((PowerEvent) -> Void)?

    private static let sourceChangedKey = "com.apple.system.powersources.source"
    private static let lowBatteryKey = "com.apple.system.powersources.lowbattery"

    private var fineGrainedSource: CFRunLoopSource?
    private var notifyTokens: [Int32] = []
    private var last: PowerSnapshot?

    public init() {}

    public func start() {
        last = Self.read()
        notifyTokens = [Self.sourceChangedKey, Self.lowBatteryKey].compactMap { key in
            var token: Int32 = 0
            let status = notify_register_dispatch(key, &token, .main) { [weak self] _ in
                MainActor.assumeIsolated { key == Self.lowBatteryKey ? self?.lowBattery() : self?.powerChanged() }
            }
            guard status == UInt32(NOTIFY_STATUS_OK) else {
                Self.logger.error("notify_register_dispatch failed for \(key, privacy: .public): \(status)")
                return nil
            }
            return token
        }
        updateFineGrainedSubscription()
    }

    public func stop() {
        notifyTokens.forEach { notify_cancel($0) }
        notifyTokens = []
        setFineGrained(false)
    }

    private func powerChanged() {
        let current = Self.read()
        defer {
            last = current
            updateFineGrainedSubscription()
        }
        guard let event = PowerTransition.event(from: last, to: current) else { return }
        onEvent?(event)
    }

    private func lowBattery() {
        let current = Self.read()
        last = current
        guard let event = PowerSubscriptionPolicy.lowBatteryEvent(current) else { return }
        onEvent?(event)
    }

    private func updateFineGrainedSubscription() {
        setFineGrained(last.map(PowerSubscriptionPolicy.needsFineGrainedUpdates) ?? false)
    }

    private func setFineGrained(_ enabled: Bool) {
        if enabled, fineGrainedSource == nil {
            let context = Unmanaged.passUnretained(self).toOpaque()
            guard let created = IOPSNotificationCreateRunLoopSource({ context in
                guard let context else { return }
                let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated { monitor.powerChanged() }
            }, context)?.takeRetainedValue() else {
                Self.logger.error("IOPSNotificationCreateRunLoopSource failed")
                return
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), created, .defaultMode)
            fineGrainedSource = created
        } else if !enabled, let source = fineGrainedSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            fineGrainedSource = nil
        }
    }

    static func read() -> PowerSnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return PowerSnapshot(isExternalPower: true, percent: nil, isCharging: false)
        }
        let sourceType = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        let external = sourceType == kIOPSACPowerValue
        let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] ?? []
        let battery = list.lazy
            .compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
            .first { ($0[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType }
        guard let battery,
              let current = battery[kIOPSCurrentCapacityKey] as? Int,
              let maximum = battery[kIOPSMaxCapacityKey] as? Int, maximum > 0
        else { return PowerSnapshot(isExternalPower: external, percent: nil, isCharging: false) }
        return PowerSnapshot(
            isExternalPower: external,
            percent: Int((Double(current) / Double(maximum) * 100).rounded()),
            isCharging: battery[kIOPSIsChargingKey] as? Bool ?? false
        )
    }
}
