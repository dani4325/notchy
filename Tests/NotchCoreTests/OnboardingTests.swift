import Foundation
import Testing
@testable import NotchCore

@MainActor
struct OnboardingTests {
    let defaults = UserDefaults(suiteName: "notchy-onboarding-\(UUID().uuidString)")!

    @Test func walksThroughEveryStepWithinBounds() {
        let model = OnboardingModel(defaults: defaults)

        #expect(model.step == .welcome)
        model.back()
        #expect(model.step == .welcome)
        model.next(); model.next(); model.next()
        #expect(model.step == .tryIt)
        #expect(model.isLastStep)
        model.next()
        #expect(model.step == .tryIt)
    }

    @Test func finishingRemembersItAndRestartingBeginsAgain() {
        let model = OnboardingModel(defaults: defaults)
        #expect(OnboardingModel.needsOnboarding(defaults: defaults))

        model.finish()
        #expect(!OnboardingModel.needsOnboarding(defaults: defaults))

        model.next()
        model.restart()
        #expect(model.step == .welcome)
    }
}
