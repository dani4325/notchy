import CoreGraphics
import Testing
@testable import NotchCore

struct LegibilityVeilTests {
    let size = CGSize(width: 400, height: 140)
    let line = CGRect(x: 120, y: 40, width: 160, height: 20)

    func alpha(_ mask: VeilMask, at point: CGPoint) -> Double {
        mask.value(at: point)
    }

    @Test func behindTheTextTheVeilReachesTheStrengthTheTextNeeds() {
        let mask = VeilMask(size: size, spots: [VeilSpot(rect: line, strength: 0.6)], feather: 12)

        for x in stride(from: line.minX, through: line.maxX, by: 8) {
            for y in stride(from: line.minY, through: line.maxY, by: 4) {
                #expect(alpha(mask, at: CGPoint(x: x, y: y)) >= 0.6 - 1e-6, "en \(x), \(y)")
            }
        }
    }

    @Test func theVeilFadesOutAwayFromTheTextWithoutAHardEdge() {
        let mask = VeilMask(size: size, spots: [VeilSpot(rect: line, strength: 0.6)], feather: 12)

        let samples = stride(from: line.maxY, through: size.height, by: 1).map { alpha(mask, at: CGPoint(x: line.midX, y: $0)) }

        #expect(samples.last! < 0.05)
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 >= $1 - 1e-9 })
        #expect(zip(samples, samples.dropFirst()).map { $0 - $1 }.max()! < 0.08)
    }

    @Test func overlappingLinesKeepTheStrongerNeed() {
        let lower = CGRect(x: 120, y: 64, width: 160, height: 16)
        let mask = VeilMask(size: size, spots: [VeilSpot(rect: line, strength: 0.3), VeilSpot(rect: lower, strength: 0.8)], feather: 12)

        #expect(alpha(mask, at: CGPoint(x: lower.midX, y: lower.midY)) >= 0.8 - 1e-6)
        #expect(alpha(mask, at: CGPoint(x: line.midX, y: line.minY)) >= 0.3 - 1e-6)
    }

    @Test func noTextMeansNoVeil() {
        let mask = VeilMask(size: size, spots: [], feather: 12)

        #expect(alpha(mask, at: CGPoint(x: 200, y: 70)) == 0)
    }

    @Test func theImageCarriesTheScrimColorWithTheMaskAsOpacity() throws {
        let mask = VeilMask(size: size, spots: [VeilSpot(rect: line, strength: 0.5)], feather: 12)

        let image = try #require(mask.image(color: RGB(red: 0, green: 0, blue: 0.2)))

        #expect(image.width == mask.width)
        #expect(image.alphaInfo == .premultipliedLast)
    }
}
