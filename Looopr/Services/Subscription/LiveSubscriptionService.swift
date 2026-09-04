import Foundation

/// Fallback used only when no RevenueCat API key is configured (local dev
/// without Secrets). Everyone is treated as premium, matching the behaviour
/// of `paywallEnabled: false`. The real implementation is
/// `RevenueCatSubscriptionService`.
final class LiveSubscriptionService: SubscriptionProviding {
    var isPaidSubscriber: Bool { true }
}
