import XCTest
@testable import Looopr

final class SubscriptionGateTests: XCTestCase {

    func testPaywallDisabledMeansEveryoneIsPremium() {
        // Pre-launch behaviour: the master switch overrides purchase state.
        XCTAssertTrue(SubscriptionGate.isPaidSubscriber(paywallEnabled: false, hasActiveEntitlement: false))
        XCTAssertTrue(SubscriptionGate.isPaidSubscriber(paywallEnabled: false, hasActiveEntitlement: true))
    }

    func testPaywallEnabledFollowsEntitlement() {
        XCTAssertFalse(SubscriptionGate.isPaidSubscriber(paywallEnabled: true, hasActiveEntitlement: false))
        XCTAssertTrue(SubscriptionGate.isPaidSubscriber(paywallEnabled: true, hasActiveEntitlement: true))
    }

    func testShippedConfigurationHasThePaywallOn() {
        // Paid features have been on sale since launch (Oct 2026). A build
        // with the switch off would give everyone Pro for free.
        XCTAssertTrue(AppConfiguration.production.freemium.paywallEnabled)
    }
}
