import CoreAudio

public struct AudioOutput: Equatable, Sendable {
    public let name: String
    let kind: AudioOutputKind
}

enum AudioOutputKind: Equatable, Sendable {
    enum AirPodsModel: Equatable, Sendable {
        case standard
        case pro
        case max
    }

    case builtInSpeakers
    case headphones
    case airPods(AirPodsModel)
    case externalSpeaker
    case display
    case airPlay

    private static let headphoneDataSource: UInt32 = 0x6864_706E
    private static let headphoneWords = ["headphone", "headset", "auricular", "earbud", "buds"]
    private static let speakerWords = ["speaker", "altavoz", "soundlink", "homepod", "sonos", "boom"]

    var symbol: String {
        switch self {
        case .builtInSpeakers: "laptopcomputer"
        case .headphones: "headphones"
        case .airPods(.standard): "airpods"
        case .airPods(.pro): "airpodspro"
        case .airPods(.max): "airpodsmax"
        case .externalSpeaker: "hifispeaker.fill"
        case .display: "display"
        case .airPlay: "airplayaudio"
        }
    }

    static func classify(transport: UInt32, dataSource: UInt32?, name: String) -> AudioOutputKind {
        let lowered = name.lowercased()
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn:
            return dataSource == headphoneDataSource ? .headphones : .builtInSpeakers
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            if lowered.contains("airpods") {
                if lowered.contains("max") { return .airPods(.max) }
                return lowered.contains("pro") ? .airPods(.pro) : .airPods(.standard)
            }
            return speakerWords.contains(where: lowered.contains) ? .externalSpeaker : .headphones
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return .display
        case kAudioDeviceTransportTypeAirPlay:
            return .airPlay
        default:
            return headphoneWords.contains(where: lowered.contains) ? .headphones : .externalSpeaker
        }
    }
}
