import Foundation
import IOKit.ps
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

@MainActor
public final class PowerMonitor {
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "power")

    public var onEvent: ((PowerEvent) -> Void)?

    private var source: CFRunLoopSource?
    private var last: PowerSnapshot?

    public init() {}

    public func start() {
        last = Self.read()
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
        source = created
    }

    public func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        source = nil
    }

    private func powerChanged() {
        let current = Self.read()
        defer { last = current }
        guard let event = PowerTransition.event(from: last, to: current) else { return }
        onEvent?(event)
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
