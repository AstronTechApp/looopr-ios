import XCTest
import CoreLocation
@testable import Looopr

/// Behaviour added in 1.5: closest loops first, locked previews for the
/// free tier, the paywall's first-search showing, the rating prompt rule,
/// and the funnel analytics events.
@MainActor
final class Release15Tests: XCTestCase {

    private func route(_ minutes: Int) -> Route {
        Route(name: "Loop \(minutes)", durationMinutes: minutes, distanceKilometers: Double(minutes) / 12,
              startLocation: Location(latitude: 52.37, longitude: 4.89))
    }

    // MARK: - 2 · Closest loops first

    func testLoopsClosestToTheAskedTimeComeFirst() {
        // Asked 30 min: ratios 22/30, 27/30, 34/30, 40/30.
        let candidates = [22, 40, 34, 27].map {
            MapboxRouteGenerationService.PentagonResult(route: route($0), ratio: Double($0) / 30, fitsLength: true)
        }
        let ordered = MapboxRouteGenerationService.closestFirst(candidates).map(\.durationMinutes)
        XCTAssertEqual(ordered, [27, 34, 22, 40])
    }

    func testFreeUsersOpenTheTwoClosestLoops() {
        // Arrival order = closest first (27, 34), the rest are locked.
        let arrivals = [27, 34, 22, 40, 45].map(route)
        let split = RouteSelectionViewModel.split(arrivals: arrivals, unlockedLimit: 2)
        XCTAssertEqual(split.open.map(\.durationMinutes), [27, 34])
        XCTAssertEqual(split.locked.map(\.durationMinutes), [22, 40, 45])
    }

    func testProSeesEverythingUnlockedShortestFirst() {
        let split = RouteSelectionViewModel.split(arrivals: [34, 27, 40].map(route), unlockedLimit: nil)
        XCTAssertEqual(split.open.map(\.durationMinutes), [27, 34, 40])
        XCTAssertTrue(split.locked.isEmpty)
    }

    func testNoLockedLoopsWhenTheSearchFindsTwoOrFewer() {
        let split = RouteSelectionViewModel.split(arrivals: [31, 28].map(route), unlockedLimit: 2)
        XCTAssertEqual(split.open.map(\.durationMinutes), [28, 31])
        XCTAssertTrue(split.locked.isEmpty)
    }

    // MARK: - 15 · Rating prompt

    func testRatingIsAskedAfterTheFirstWalkOfTenMinutes() {
        XCTAssertTrue(FinishWalkViewModel.shouldAskForReview(durationSeconds: 600, completedWalks: 1, alreadyAskedThisVersion: false))
    }

    func testShortWalksAndRepeatsAreNotAsked() {
        XCTAssertFalse(FinishWalkViewModel.shouldAskForReview(durationSeconds: 540, completedWalks: 3, alreadyAskedThisVersion: false))
        XCTAssertFalse(FinishWalkViewModel.shouldAskForReview(durationSeconds: 1800, completedWalks: 0, alreadyAskedThisVersion: false))
        XCTAssertFalse(FinishWalkViewModel.shouldAskForReview(durationSeconds: 1800, completedWalks: 2, alreadyAskedThisVersion: true))
    }

    // MARK: - 11 · Analytics events

    func testNewEventNamesAndProperties() {
        XCTAssertEqual(AnalyticsEvent.paywallShown(source: "first_search").name, "paywall_shown")
        XCTAssertEqual(AnalyticsEvent.paywallDismissed(source: "locked_route").name, "paywall_dismissed")
        XCTAssertEqual(AnalyticsEvent.lockedFeatureTapped(feature: "food").name, "locked_feature_tapped")
        XCTAssertEqual(AnalyticsEvent.onboardingPageViewed(page: 2).name, "onboarding_page_viewed")
        XCTAssertEqual(AnalyticsEvent.onboardingCompleted(skipped: true, lastPage: 1).name, "onboarding_completed")
        XCTAssertEqual(AnalyticsEvent.accountPromptShown(reason: "after_walk").name, "account_prompt_shown")
        XCTAssertEqual(AnalyticsEvent.signInCompleted(method: "apple", reason: "share").name, "sign_in_completed")
        XCTAssertEqual(AnalyticsEvent.locationPermission(status: "granted").name, "location_permission")

        guard case .string(let source)? = AnalyticsEvent.paywallShown(source: "first_search").properties["source"] else {
            return XCTFail("paywall_shown carries its source")
        }
        XCTAssertEqual(source, "first_search")
        guard case .bool(true)? = AnalyticsEvent.onboardingCompleted(skipped: true, lastPage: 1).properties["skipped"] else {
            return XCTFail("onboarding_completed carries skipped")
        }
        guard case .int(3)? = AnalyticsEvent.routeGenerated(count: 5, minutes: 30, firstRouteSeconds: 1, totalSeconds: 2,
                                                              stoppedEarly: false, closestOnly: false, locked: 3).properties["locked"] else {
            return XCTFail("route_generated carries the locked count")
        }
    }

    func testPaywallSourcesAreStable() {
        // These strings are stored in analytics; renaming one splits the funnel.
        XCTAssertEqual(PaywallSource.settings.rawValue, "settings")
        XCTAssertEqual(PaywallSource.upgradeCard.rawValue, "upgrade_card")
        XCTAssertEqual(PaywallSource.lockedRoute.rawValue, "locked_route")
        XCTAssertEqual(PaywallSource.foodLock.rawValue, "food_lock")
        XCTAssertEqual(PaywallSource.firstSearch.rawValue, "first_search")
    }

    // MARK: - 12 · Account prompt reasons

    func testAccountPromptReasonsHaveAnalyticsNames() {
        XCTAssertEqual(AccountPrompt.Reason.afterWalk.analyticsName, "after_walk")
        XCTAssertEqual(AccountPrompt.Reason.shareRoute.analyticsName, "share")
        XCTAssertEqual(AccountPrompt.Reason.feedback.analyticsName, "feedback")
        XCTAssertEqual(AccountPrompt.Reason.settings.analyticsName, "settings")
    }
}
