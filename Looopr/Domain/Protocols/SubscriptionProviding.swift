import Foundation

/// Provides subscription/purchase status for freemium gating.
/// Sprint 7 wires this to StoreKit 2.
protocol SubscriptionProviding: Sendable {
    /// True when the user has an active paid subscription.
    var isPaidSubscriber: Bool { get }
}
