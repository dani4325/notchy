@preconcurrency import AppKit
import ApplicationServices
import os

@MainActor
public final class MediaKeyTap {
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "mediakeys")
    nonisolated private static let systemDefinedType = CGEventType(rawValue: 14)!
    nonisolated private static let auxControlButtonsSubtype: Int16 = 8

    var onKey: ((MediaKey) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    public var isActive: Bool { tap != nil }

    public init() {}

    public func start() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = CGEventMask(1) << Self.systemDefinedType.rawValue
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<MediaKeyTap>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    MainActor.assumeIsolated { owner.reenable() }
                    return Unmanaged.passUnretained(event)
                }
                guard let key = MediaKeyTap.mediaKey(type: type, event: event) else {
                    return Unmanaged.passUnretained(event)
                }
                let handled = MainActor.assumeIsolated { owner.onKey?(key) ?? false }
                return handled ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            Self.logger.error("event tap could not be created")
            return
        }
        let runLoopSource = CFMachPortCreateRunLoopSource(nil, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        tap = created
        source = runLoopSource
    }

    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    nonisolated static func mediaKey(type: CGEventType, event: CGEvent) -> MediaKey? {
        guard type == systemDefinedType,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == auxControlButtonsSubtype
        else { return nil }
        return MediaKey(data1: nsEvent.data1)
    }
}
