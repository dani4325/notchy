import Accelerate
import Foundation

final class SpectrumAnalyzer: @unchecked Sendable {
    static let frameSize = 1024
    static let minimumFrequency = 60.0
    static let maximumFrequency = 12_000.0
    static let floorDecibels: Float = -62
    static let attack: Float = 0.6
    static let release: Float = 0.18

    private let bandCount: Int
    private let sampleRate: Double
    private let fft: vDSP.FFT<DSPSplitComplex>
    private let window: [Float]
    private let bandEdges: [Int]

    init(bandCount: Int, sampleRate: Double) {
        self.bandCount = bandCount
        self.sampleRate = sampleRate
        fft = vDSP.FFT(log2n: vDSP_Length(log2(Double(Self.frameSize))), radix: .radix2, ofType: DSPSplitComplex.self)!
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: Self.frameSize, isHalfWindow: false)
        let binWidth = sampleRate / Double(Self.frameSize)
        let ratio = Self.maximumFrequency / Self.minimumFrequency
        bandEdges = (0...bandCount).map { index in
            let frequency = Self.minimumFrequency * pow(ratio, Double(index) / Double(bandCount))
            return min(max(Int(frequency / binWidth), 1), Self.frameSize / 2 - 1)
        }
    }

    func levels(for samples: [Float]) -> [Float] {
        guard samples.count >= Self.frameSize else { return [Float](repeating: 0, count: bandCount) }
        let windowed = vDSP.multiply(Array(samples.prefix(Self.frameSize)), window)
        let half = Self.frameSize / 2
        var real = [Float](repeating: 0, count: half)
        var imaginary = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)

        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imaginaryPointer.baseAddress!)
                windowed.withUnsafeBytes { raw in
                    vDSP.convert(interleavedComplexVector: Array(raw.bindMemory(to: DSPComplex.self)), toSplitComplexVector: &split)
                }
                fft.forward(input: split, output: &split)
                vDSP.absolute(split, result: &magnitudes)
            }
        }

        let scale = 2 / Float(Self.frameSize)
        return (0..<bandCount).map { band in
            let range = bandEdges[band]..<max(bandEdges[band + 1], bandEdges[band] + 1)
            let peak = (magnitudes[range].max() ?? 0) * scale
            guard peak > 0 else { return 0 }
            let decibels = 20 * log10(peak)
            return min(max((decibels - Self.floorDecibels) / -Self.floorDecibels, 0), 1)
        }
    }

    static func smooth(previous: [Float], next: [Float]) -> [Float] {
        guard previous.count == next.count else { return next }
        return zip(previous, next).map { old, new in
            let factor = new > old ? attack : release
            return old + (new - old) * factor
        }
    }
}

enum SimulatedSpectrum {
    static func levels(at time: TimeInterval, bandCount: Int) -> [Float] {
        (0..<bandCount).map { band in
            let phase = time * (1.6 + Double(band) * 0.37) + Double(band) * 1.3
            let wave = (sin(phase) + sin(phase * 0.53 + 0.8)) / 4 + 0.5
            return Float(0.15 + wave * 0.85)
        }
    }
}
