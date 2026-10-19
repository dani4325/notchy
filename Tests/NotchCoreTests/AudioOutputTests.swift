import AppKit
import CoreAudio
import Testing
@testable import NotchCore

struct AudioOutputTests {
    static let internalSpeakers: UInt32 = 0x6973_706B
    static let headphoneJack: UInt32 = 0x6864_706E

    @Test func builtInOutputUsesTheDataSourceToTellSpeakersFromHeadphones() {
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeBuiltIn, dataSource: Self.internalSpeakers, name: "Altavoces del MacBook Pro") == .builtInSpeakers)
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeBuiltIn, dataSource: Self.headphoneJack, name: "Auriculares externos") == .headphones)
    }

    @Test func bluetoothDevicesAreClassifiedByName() {
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeBluetooth, dataSource: nil, name: "AirPods Pro de Dani") == .airPods(.pro))
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeBluetooth, dataSource: nil, name: "AirPods Max") == .airPods(.max))
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeBluetoothLE, dataSource: nil, name: "AirPods de Dani") == .airPods(.standard))
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeBluetooth, dataSource: nil, name: "WH-1000XM5") == .headphones)
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeBluetooth, dataSource: nil, name: "JBL Flip Speaker") == .externalSpeaker)
    }

    @Test func otherTransportsMapToTheirKind() {
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeHDMI, dataSource: nil, name: "LG UltraFine") == .display)
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeDisplayPort, dataSource: nil, name: "Studio Display") == .display)
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeAirPlay, dataSource: nil, name: "Salón") == .airPlay)
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeUSB, dataSource: nil, name: "Scarlett 2i2") == .externalSpeaker)
        #expect(AudioOutputKind.classify(transport: kAudioDeviceTransportTypeUSB, dataSource: nil, name: "USB Headset") == .headphones)
    }

    @Test func everyKindHasASystemSymbol() {
        let kinds: [AudioOutputKind] = [.builtInSpeakers, .headphones, .airPods(.standard), .airPods(.pro), .airPods(.max), .externalSpeaker, .display, .airPlay]
        for kind in kinds {
            #expect(NSImage(systemSymbolName: kind.symbol, accessibilityDescription: nil) != nil, "\(kind.symbol)")
        }
    }
}
