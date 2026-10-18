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

    @Test func fadeThemeBehavesLikeReducedMotion() {
        let policy = MotionPolicy(reduceMotion: false, openAnimation: .fade)

        #expect(!policy.animatesShape)
        #expect(policy.shapeAnimation(expanding: true) == nil)
    }

    @Test func reduceMotionWinsOverAnyThemeAnimation() {
        for animation in OpenAnimation.allCases {
            #expect(!MotionPolicy(reduceMotion: true, openAnimation: animation).animatesShape)
        }
    }

    @Test func everyAnimatedThemeOpensWithAnimation() {
        for animation in [OpenAnimation.spring, .bouncy, .smooth] {
            #expect(MotionPolicy(reduceMotion: false, openAnimation: animation).shapeAnimation(expanding: true) != nil)
        }
    }
}
