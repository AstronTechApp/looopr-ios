import Foundation

protocol PedometerProviding: AnyObject, Sendable {
    /// Latest live count since `startCounting()`. May lag the real figure by
    /// several seconds — CoreMotion batches pedometer updates.
    var currentStepCount: Int { get }
    var isAvailable: Bool { get }
    /// True when Motion & Fitness access is denied or restricted, so a zero
    /// count means "no permission", not "no steps".
    var isAuthorizationDenied: Bool { get }
    func startCounting()
    /// Stops live updates and returns the authoritative step total for the
    /// walk, queried from CoreMotion's history rather than read from the
    /// last live update (which can be stale or never arrive on short walks).
    @discardableResult
    func stopCounting() async -> Int
}
