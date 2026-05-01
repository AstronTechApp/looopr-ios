import Foundation

/// Stub implementation — returns true for Mapbox testing.
/// Revert to `false` before shipping; Sprint 7 wires this to StoreKit 2.
final class LiveSubscriptionService: SubscriptionProviding {
    var isPaidSubscriber: Bool { true }
}
