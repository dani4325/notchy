import AudioToolbox
import CoreAudio
import Foundation
import os

final class SystemAudioTap: @unchecked Sendable {
    enum TapError: Error {
        case tapCreation(OSStatus)
        case aggregateCreation(OSStatus)
        case ioProc(OSStatus)
        case start(OSStatus)
    }

    static let bandCount = 6
    private static let publishInterval: UInt64 = 33_000_000
    private static let logger = Logger(subsystem: "com.danirubio.notchy", category: "visualizer")

    var onLevels: (@Sendable ([Float], Bool) -> Void)?

    private let queue = DispatchQueue(label: "com.danirubio.notchy.visualizer", qos: .userInteractive)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var analyzer = SpectrumAnalyzer(bandCount: bandCount, sampleRate: 48_000)
    private var samples: [Float] = []
    private var lastPublish: UInt64 = 0

    func start() throws {
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var tap = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(description, &tap)
        guard status == noErr else { throw TapError.tapCreation(status) }
        tapID = tap
        analyzer = SpectrumAnalyzer(bandCount: Self.bandCount, sampleRate: sampleRate(of: tap))

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Notchy Visualizer",
            kAudioAggregateDeviceUIDKey: "com.danirubio.notchy.visualizer.\(description.uuid.uuidString)",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        var device = AudioObjectID(kAudioObjectUnknown)
        status = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &device)
        guard status == noErr else {
            stop()
            throw TapError.aggregateCreation(status)
        }
        aggregateID = device

        status = AudioDeviceCreateIOProcIDWithBlock(&procID, device, queue) { [weak self] _, input, _, _, _ in
            self?.consume(input)
        }
        guard status == noErr else {
            stop()
            throw TapError.ioProc(status)
        }
        status = AudioDeviceStart(device, procID)
        guard status == noErr else {
            stop()
            throw TapError.start(status)
        }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
        samples = []
    }

    private func sampleRate(of tap: AudioObjectID) -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &format)
        guard status == noErr, format.mSampleRate > 0 else {
            Self.logger.error("tap format unavailable (\(status))")
            return 48_000
        }
        return format.mSampleRate
    }

    private func consume(_ input: UnsafePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let first = buffers.first, let data = first.mData else { return }
        let channels = Int(max(first.mNumberChannels, 1))
        let frames = Int(first.mDataByteSize) / MemoryLayout<Float32>.size / channels
        let pointer = data.assumingMemoryBound(to: Float32.self)

        var mono = [Float](repeating: 0, count: frames)
        for frame in 0..<frames {
            var sum: Float = 0
            for channel in 0..<channels { sum += pointer[frame * channels + channel] }
            mono[frame] = sum / Float(channels)
        }
        samples.append(contentsOf: mono)
        if samples.count > SpectrumAnalyzer.frameSize * 2 {
            samples.removeFirst(samples.count - SpectrumAnalyzer.frameSize)
        }

        let now = DispatchTime.now().uptimeNanoseconds
        guard samples.count >= SpectrumAnalyzer.frameSize, now - lastPublish >= Self.publishInterval else { return }
        lastPublish = now
        let frame = Array(samples.suffix(SpectrumAnalyzer.frameSize))
        let isSilent = frame.allSatisfy { abs($0) < 0.000_01 }
        onLevels?(analyzer.levels(for: frame), isSilent)
    }
}
