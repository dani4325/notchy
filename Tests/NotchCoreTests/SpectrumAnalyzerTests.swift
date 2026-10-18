import Foundation
import Testing
@testable import NotchCore

struct SpectrumAnalyzerTests {
    let sampleRate = 48_000.0

    func sine(_ frequency: Double, amplitude: Float = 0.8, count: Int = SpectrumAnalyzer.frameSize) -> [Float] {
        (0..<count).map { amplitude * Float(sin(2 * .pi * frequency * Double($0) / sampleRate)) }
    }

    @Test func silenceProducesZeroLevels() {
        let analyzer = SpectrumAnalyzer(bandCount: 6, sampleRate: sampleRate)

        let levels = analyzer.levels(for: [Float](repeating: 0, count: SpectrumAnalyzer.frameSize))

        #expect(levels.count == 6)
        #expect(levels.allSatisfy { $0 == 0 })
    }

    @Test func lowToneLightsTheFirstBandsHighToneTheLast() throws {
        let analyzer = SpectrumAnalyzer(bandCount: 6, sampleRate: sampleRate)

        let bass = analyzer.levels(for: sine(90))
        let treble = analyzer.levels(for: sine(9_000))

        let bassPeak = try #require(bass.indices.max { bass[$0] < bass[$1] })
        let treblePeak = try #require(treble.indices.max { treble[$0] < treble[$1] })
        #expect(bassPeak <= 1)
        #expect(treblePeak >= 4)
    }

    @Test func levelsStayNormalized() {
        let analyzer = SpectrumAnalyzer(bandCount: 6, sampleRate: sampleRate)

        let loud = analyzer.levels(for: sine(440, amplitude: 1))

        #expect(loud.allSatisfy { (0...1).contains($0) })
        #expect(loud.contains { $0 > 0.4 })
    }

    @Test func smoothingRisesFastAndFallsSlowly() {
        let up = SpectrumAnalyzer.smooth(previous: [0], next: [1])
        let down = SpectrumAnalyzer.smooth(previous: [1], next: [0])

        #expect(up[0] > 0.5)
        #expect(down[0] > 0.5 && down[0] < 1)
    }

    @Test func simulatedLevelsAreDeterministicAndBounded() {
        let levels = SimulatedSpectrum.levels(at: 12.34, bandCount: 6)

        #expect(levels == SimulatedSpectrum.levels(at: 12.34, bandCount: 6))
        #expect(levels.allSatisfy { (0.15...1).contains($0) })
    }
}
