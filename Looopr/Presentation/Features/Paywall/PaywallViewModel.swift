import Foundation
import RevenueCat

/// Drives `PaywallView`. Purchase and restore flows themselves run inside
/// RevenueCatUI's `PaywallView`, which talks to `Purchases.shared` directly —
/// this view model only tracks whether a paywall can be shown at all and
/// reacts to the completion callbacks RevenueCatUI reports back.
@MainActor @Observable
final class PaywallViewModel {

    /// True once the entitlement stream has confirmed `looopr_pro` is
    /// active. Set from two independent sources: RevenueCatUI's
    /// `onPurchaseCompleted`/`onRestoreCompleted` callbacks (fast, but have
    /// known reliability issues on some SDK versions — see RevenueCat
    /// community reports) and our own `customerInfoStream` observation
    /// below (slower to react, but always correct). Whichever fires first
    /// wins, so the paywall dismisses reliably either way.
    private(set) var didUnlock = false

    private let subscriptionService: RevenueCatSubscriptionService?
    private let analytics: AnalyticsTracking
    private let logger = AppLogger(category: "Paywall")
    private var entitlementObservationTask: Task<Void, Never>?

    init(
        subscriptionService: RevenueCatSubscriptionService? = nil,
        analytics: AnalyticsTracking = ServiceContainer.shared.resolve(AnalyticsTracking.self)
    ) {
        self.subscriptionService = subscriptionService
            ?? ServiceContainer.shared.resolveOptional(RevenueCatSubscriptionService.self)
        self.analytics = analytics
    }

    /// Redundant, callback-independent path to `didUnlock`: watches
    /// RevenueCat's own entitlement stream so the paywall still dismisses
    /// even if RevenueCatUI's completion callbacks never fire.
    func observeEntitlement() {
        guard entitlementObservationTask == nil, let subscriptionService else { return }
        if subscriptionService.hasActiveEntitlement {
            didUnlock = true
            return
        }
        entitlementObservationTask = Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard !Task.isCancelled else { return }
                if customerInfo.entitlements[RevenueCatSubscriptionService.entitlementID]?.isActive == true {
                    self?.didUnlock = true
                    return
                }
            }
        }
    }

    /// Stops the stream observer when the paywall goes away so it doesn't
    /// linger until RevenueCat's next emission. Called from the view's
    /// `onDisappear` (a `deinit` can't touch MainActor-isolated state on an
    /// `@Observable` class). Safe to call repeatedly; `observeEntitlement()`
    /// restarts it if the view reappears. The task holds only `weak self`,
    /// so nothing leaks if it outlives the view model briefly.
    func stopObservingEntitlement() {
        entitlementObservationTask?.cancel()
        entitlementObservationTask = nil
    }

    /// RevenueCatUI's `PaywallView` requires `Purchases` to already be
    /// configured (it force-unwraps `Purchases.shared` internally), which
    /// is only true when a RevenueCat API key is present — see
    /// `Secrets.hasRevenueCatKey`.
    var isConfigured: Bool { subscriptionService != nil }

    var alreadyPremium: Bool { subscriptionService?.hasActiveEntitlement == true }

    func trackShown() {
        analytics.track(.paywallShown)
    }

    func handlePurchaseCompleted(_ customerInfo: CustomerInfo) {
        let unlocked = customerInfo.entitlements[RevenueCatSubscriptionService.entitlementID]?.isActive == true
        logger.info("Purchase completed via paywall; looopr_pro active: \(unlocked)")
        if unlocked {
            analytics.track(.subscriptionStarted)
            didUnlock = true
        }
    }

    func handleRestoreCompleted(_ customerInfo: CustomerInfo) {
        let unlocked = customerInfo.entitlements[RevenueCatSubscriptionService.entitlementID]?.isActive == true
        logger.info("Restore completed via paywall; looopr_pro active: \(unlocked)")
        if unlocked {
            didUnlock = true
        }
    }
}
