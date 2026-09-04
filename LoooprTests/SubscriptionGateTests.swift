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

    func testShippedConfigurationKeepsPaywallDark() {
        // Guard rail: this test starts failing the day the switch is flipped,
        // as a reminder to verify products, offering, and entitlement are
        // live in RevenueCat before shipping that build.
        XCTAssertFalse(AppConfiguration.production.freemium.paywallEnabled)
    }
}
