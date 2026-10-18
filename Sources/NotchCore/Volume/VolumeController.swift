import AudioToolbox
import CoreAudio
import Foundation
import os

@MainActor
public final class VolumeController {
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "volume")

    public var onChange: ((VolumeReading) -> Void)?

    private var device = AudioObjectID(kAudioObjectUnknown)
    private var last: VolumeReading?
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var valueListener: AudioObjectPropertyListenerBlock?

    private static var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    public init() {}

    public func start() {
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.attachToDefaultDevice() }
        }
        deviceListener = listener
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &Self.defaultOutputAddress, .main, listener)
        attachToDefaultDevice()
    }

    public func stop() {
        detachFromDevice()
        if let deviceListener {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &Self.defaultOutputAddress, .main, deviceListener)
        }
        deviceListener = nil
    }

    public var current: VolumeReading? { read() }

    func apply(_ key: MediaKey) {
        guard key.isDown, let reading = read() else { return }
        switch key.kind {
        case .mute:
            guard !key.isRepeat else { return }
            setMuted(!reading.isMuted)
        case .volumeUp, .volumeDown:
            let level = VolumeStep.apply(key.kind, to: reading.isMuted ? 0 : reading.level)
            if reading.isMuted, key.kind == .volumeUp { setMuted(false) }
            setLevel(level)
        }
    }

    private func attachToDefaultDevice() {
        detachFromDevice()
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var newDevice = AudioObjectID(kAudioObjectUnknown)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &Self.defaultOutputAddress, 0, nil, &size, &newDevice)
        guard status == noErr, newDevice != kAudioObjectUnknown else {
            Self.logger.error("no default output device (\(status))")
            return
        }
        device = newDevice
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.valueChanged() }
        }
        valueListener = listener
        AudioObjectAddPropertyListenerBlock(device, &Self.volumeAddress, .main, listener)
        AudioObjectAddPropertyListenerBlock(device, &Self.muteAddress, .main, listener)
        last = read()
    }

    private func detachFromDevice() {
        if let valueListener, device != kAudioObjectUnknown {
            AudioObjectRemovePropertyListenerBlock(device, &Self.volumeAddress, .main, valueListener)
            AudioObjectRemovePropertyListenerBlock(device, &Self.muteAddress, .main, valueListener)
        }
        valueListener = nil
        device = AudioObjectID(kAudioObjectUnknown)
    }

    private func valueChanged() {
        guard let reading = read() else { return }
        defer { last = reading }
        guard VolumeReading.isChange(from: last, to: reading) else { return }
        onChange?(reading)
    }

    private func read() -> VolumeReading? {
        guard device != kAudioObjectUnknown else { return nil }
        var level = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &Self.volumeAddress, 0, nil, &size, &level) == noErr else { return nil }
        var muted = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        let hasMute = AudioObjectGetPropertyData(device, &Self.muteAddress, 0, nil, &size, &muted) == noErr
        return VolumeReading(level: level, isMuted: hasMute && muted != 0)
    }

    private func setLevel(_ level: Float) {
        var value = Float32(level)
        let status = AudioObjectSetPropertyData(device, &Self.volumeAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        if status != noErr { Self.logger.error("set volume failed (\(status))") }
    }

    private func setMuted(_ muted: Bool) {
        var value = UInt32(muted ? 1 : 0)
        let status = AudioObjectSetPropertyData(device, &Self.muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        if status != noErr { Self.logger.error("set mute failed (\(status))") }
    }
}
