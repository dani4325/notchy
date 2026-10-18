import Foundation
import Observation

public enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case permissions
    case theme
    case tryIt
}

@MainActor
@Observable
public final class OnboardingModel {
    public static let windowID = "welcome"
    private static let completedKey = "onboardingCompleted"

    public private(set) var step = OnboardingStep.welcome
    public var onTryPanel: (() -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public static func needsOnboarding(defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: completedKey)
    }

    public var isLastStep: Bool { step == OnboardingStep.allCases.last }

    public func next() {
        step = OnboardingStep(rawValue: step.rawValue + 1) ?? step
    }

    public func back() {
        step = OnboardingStep(rawValue: step.rawValue - 1) ?? step
    }

    public func restart() {
        step = .welcome
    }

    public func finish() {
        defaults.set(true, forKey: Self.completedKey)
    }

    public func tryPanel() {
        onTryPanel?()
    }
}
