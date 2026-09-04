import Foundation
import RevenueCat

/// Pure gating decision, split out so it's unit-testable without the SDK.
enum SubscriptionGate {
    /// While the paywall is disabled (pre-launch), everyone is premium no
    /// matter what RevenueCat says. Once enabled, the entitlement decides.
    static func isPaidSubscriber(paywallEnabled: Bool, hasActiveEntitlement: Bool) -> Bool {
        paywallEnabled ? hasActiveEntitlement : true
    }
}

/// Identifiers for the three products configured in App Store Connect and
/// mirrored as packages in the RevenueCat dashboard's default offering.
/// These are the *product* identifiers — RevenueCat lets a package carry a
/// different (or RevenueCat-reserved `$rc_*`) identifier, so gating logic
/// should prefer `Package.storeProduct.productIdentifier` over the package
/// identifier itself when it needs to know exactly which product sold.
enum LoooprProductID {
    /// EUR 2,99 / month, no introductory offer.
    static let monthly = "nl.astrontech.looopr.pro.monthly"
    /// EUR 24,99 / year (30% off monthly) with a 1-week free trial.
    /// Apple grants one introductory offer per *subscription group*, so the
    /// trial lives here and a user who trials annual cannot also trial monthly.
    static let yearly = "nl.astrontech.looopr.pro.yearly"
}

/// RevenueCat-backed implementation of `SubscriptionProviding`.
///
/// Configured once at app launch (from `registerProductionServices`) when a
/// RevenueCat API key is present in Secrets. Keeps a cached entitlement flag
/// up to date via `customerInfoStream` — the source of truth for entitlement
/// state, independent of whether any particular purchase/restore callback
/// fires — and ties the RevenueCat identity to the Supabase user id so
/// purchases follow the account across devices.
final class RevenueCatSubscriptionService: SubscriptionProviding, @unchecked Sendable {

    /// The entitlement identifier configured in the RevenueCat dashboard.
    static let entitlementID = "looopr_pro"

    private let paywallEnabled: Bool
    private let logger = AppLogger(category: "Subscription")

    private let stateLock = NSLock()
    private var _hasActiveEntitlement = false
    private var streamTask: Task<Void, Never>?

    private(set) var hasActiveEntitlement: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _hasActiveEntitlement }
        set { stateLock.lock(); _hasActiveEntitlement = newValue; stateLock.unlock() }
    }

    var isPaidSubscriber: Bool {
        SubscriptionGate.isPaidSubscriber(
            paywallEnabled: paywallEnabled,
            hasActiveEntitlement: hasActiveEntitlement
        )
    }

    init(apiKey: String, paywallEnabled: Bool) {
        self.paywallEnabled = paywallEnabled

        #if DEBUG
        Purchases.logLevel = .warn
        #else
        Purchases.logLevel = .error
        #endif

        // StoreKit 2 is used automatically when available; no explicit
        // opt-in needed on current SDK versions. Identity (appUserID) is
        // deliberately left anonymous here — `syncIdentity(appUserID:)`
        // below ties the RevenueCat user to the Supabase account once
        // auth state is known, so purchases made before sign-in still
        // transfer correctly via `logIn`.
        Purchases.configure(withAPIKey: apiKey)

        streamTask = Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                self?.apply(customerInfo)
            }
        }
    }

    deinit {
        streamTask?.cancel()
    }

    private func apply(_ customerInfo: CustomerInfo) {
        let active = customerInfo.entitlements[Self.entitlementID]?.isActive == true
        hasActiveEntitlement = active
        logger.info("Entitlement '\(Self.entitlementID)' active: \(active)")
    }

    /// Re-reads the cached CustomerInfo from RevenueCat (no network call
    /// unless the local cache is stale) and refreshes `hasActiveEntitlement`.
    /// Useful right after returning to the app (e.g. Settings appearing)
    /// so UI reflects any change made in the Customer Center or another
    /// device without waiting for the next stream tick.
    @discardableResult
    func refreshCustomerInfo() async -> CustomerInfo? {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            apply(customerInfo)
            return customerInfo
        } catch {
            logger.error("Failed to refresh customer info: \(error)")
            return nil
        }
    }

    // MARK: - Identity

    /// Ties (or unties) the RevenueCat identity to the signed-in Supabase
    /// user. Called from AuthService on session changes. Fire-and-forget:
    /// failures only mean the purchase stays on the anonymous id.
    func syncIdentity(appUserID: String?) {
        Task { [weak self] in
            do {
                if let appUserID {
                    guard Purchases.shared.appUserID != appUserID else { return }
                    let (customerInfo, _) = try await Purchases.shared.logIn(appUserID)
                    self?.apply(customerInfo)
                } else if !Purchases.shared.isAnonymous {
                    let customerInfo = try await Purchases.shared.logOut()
                    self?.apply(customerInfo)
                }
            } catch {
                self?.logger.error("RevenueCat identity sync failed: \(error)")
            }
        }
    }

    // MARK: - Offerings & purchases
    //
    // The paywall UI itself is presented via RevenueCatUI's `PaywallView`
    // (see Presentation/Features/Paywall), which fetches offerings and
    // drives purchase/restore internally. The methods below remain for
    // call sites that need programmatic access — tests, a future "Buy
    // Lifetime" quick action, etc. — without going through paywall UI.

    /// Packages of the current offering, keyed by product so callers can
    /// find "the yearly package" without caring whether RevenueCat resolved
    /// its `packageType` to `.annual` or left it `.custom`.
    func currentPackages() async throws -> [Package] {
        try await Purchases.shared.offerings().current?.availablePackages ?? []
    }

    /// Runs the App Store purchase flow for a package.
    /// Returns true when the `looopr_pro` entitlement is active afterwards.
    func purchase(_ package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)
        apply(result.customerInfo)
        guard !result.userCancelled else { return false }
        return result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
    }

    /// Restores prior purchases (required by App Store review).
    /// Returns true when the `looopr_pro` entitlement is active afterwards.
    func restorePurchases() async throws -> Bool {
        let customerInfo = try await Purchases.shared.restorePurchases()
        apply(customerInfo)
        return customerInfo.entitlements[Self.entitlementID]?.isActive == true
    }
}

// MARK: - Error presentation

extension RevenueCatSubscriptionService {
    /// Turns a thrown purchase/restore error into copy that's safe to show
    /// a user — RevenueCat's `ErrorCode` cases carry a `localizedDescription`
    /// but a couple of common ones read better rephrased for a paywall alert.
    static func userFacingMessage(for error: Error) -> String? {
        guard let rcError = error as? ErrorCode else {
            return error.localizedDescription
        }
        switch rcError {
        case .purchaseCancelledError:
            // Not really an error — the user backed out of the App Store
            // sheet. Callers should treat this as a silent no-op, not an alert.
            return nil
        case .paymentPendingError:
            return "Your purchase is pending approval (e.g. Ask to Buy) and will unlock automatically once approved."
        case .networkError, .offlineConnectionError:
            return "Couldn't reach the App Store. Check your connection and try again."
        case .productAlreadyPurchasedError:
            return "You already own this. Try Restore Purchases instead."
        default:
            return rcError.localizedDescription
        }
    }
}
