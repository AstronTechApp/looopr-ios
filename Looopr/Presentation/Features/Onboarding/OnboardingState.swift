import Foundation

/// Tracks whether the first-launch onboarding has been shown.
///
/// Stored in UserDefaults so it survives sign-out. Existing users who already
/// have a session when they update are marked as completed on first launch so
/// they never see the intro (see `AppRootView`).
@Observable
final class OnboardingState {
    static let shared = OnboardingState()

    private static let key = "onboarding.hasCompleted"
    private let defaults: UserDefaults

    private(set) var hasCompleted: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompleted = defaults.bool(forKey: Self.key)
    }

    func markCompleted() {
        guard !hasCompleted else { return }
        hasCompleted = true
        defaults.set(true, forKey: Self.key)
    }

    #if DEBUG
    /// Debug-only helper so the intro can be re-tested without reinstalling.
    func reset() {
        hasCompleted = false
        defaults.removeObject(forKey: Self.key)
    }
    #endif
}
