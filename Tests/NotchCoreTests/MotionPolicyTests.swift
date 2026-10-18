import Testing
@testable import NotchCore

struct MotionPolicyTests {
    @Test func fullMotionAnimatesShapeWithSpring() {
        let policy = MotionPolicy(reduceMotion: false)

        #expect(policy.animatesShape)
        #expect(policy.contentScale < 1)
    }

    @Test func reducedMotionSnapsShapeAndOnlyFadesContent() {
        let policy = MotionPolicy(reduceMotion: true)

        #expect(!policy.animatesShape)
        #expect(policy.contentScale == 1)
        #expect(policy.shapeAnimation(expanding: true) == nil)
        #expect(policy.shapeAnimation(expanding: false) == nil)
    }
}
