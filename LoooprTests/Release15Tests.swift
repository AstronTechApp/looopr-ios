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

    // MARK: - Route card row and equal POI tabs

    func testRouteCardRowSaysCafesComeWithProOnTheFreeTier() {
        XCTAssertEqual(RouteCardPOIRowText.title(isFreeTier: true), L10n.RouteSelection.poiRowTitleFree)
        XCTAssertEqual(RouteCardPOIRowText.subtitle(isFreeTier: true), L10n.RouteSelection.poiRowSubtitleFree)
        XCTAssertEqual(RouteCardPOIRowText.title(isFreeTier: false), L10n.RouteSelection.poiRowTitlePro)
        XCTAssertEqual(RouteCardPOIRowText.subtitle(isFreeTier: false), L10n.RouteSelection.poiRowSubtitlePro)
        XCTAssertNotEqual(RouteCardPOIRowText.title(isFreeTier: true), RouteCardPOIRowText.title(isFreeTier: false))
    }

    func testFoodTabShowsProInsteadOfACountOnTheFreeTier() {
        // Free: nothing is fetched from Google, so there is no number.
        XCTAssertEqual(POIListView.foodCountLabel(isLocked: true, hasFetched: false, count: 0), "Pro")
        XCTAssertEqual(POIListView.foodCountLabel(isLocked: true, hasFetched: true, count: 7), "Pro")
        // Pro: a teaser until the places are in, then the real count.
        XCTAssertEqual(POIListView.foodCountLabel(isLocked: false, hasFetched: false, count: 0), "10+")
        XCTAssertEqual(POIListView.foodCountLabel(isLocked: false, hasFetched: true, count: 7), "7")
    }

    // MARK: - Appearance setting

    func testAppearanceFollowsThePhoneUnlessTheUserChooses() {
        XCTAssertEqual(SettingsManager.Appearance.allCases, [.system, .light, .dark])
        XCTAssertEqual(SettingsManager.Appearance.system.interfaceStyle, .unspecified)
        XCTAssertEqual(SettingsManager.Appearance.light.interfaceStyle, .light)
        XCTAssertEqual(SettingsManager.Appearance.dark.interfaceStyle, .dark)
        // Stored values must not change: they are what is saved on the phone.
        XCTAssertEqual(SettingsManager.Appearance.allCases.map(\.rawValue), ["system", "light", "dark"])
    }

    func testAppearanceChoiceIsSaved() {
        let settings = SettingsManager.shared
        let before = settings.appearance
        defer { settings.appearance = before }
        settings.appearance = .dark
        XCTAssertEqual(UserDefaults.standard.string(forKey: "settings.appearance"), "dark")
        settings.appearance = .system
        XCTAssertEqual(UserDefaults.standard.string(forKey: "settings.appearance"), "system")
    }

    func testRouteSelectedSaysWhichPartOfTheCardWasTapped() {
        let event = AnalyticsEvent.routeSelected(routeId: UUID(), durationMinutes: 30, distanceKm: 2.8, source: "poi_row")
        XCTAssertEqual(event.name, "route_selected")
        guard case .string(let source)? = event.properties["source"] else {
            return XCTFail("route_selected carries the tapped part of the card")
        }
        XCTAssertEqual(source, "poi_row")
    }

    // MARK: - Sights: failed search vs "no sights", per-loop cache

    private func loop(offset: Double = 0) -> [CLLocationCoordinate2D] {
        (0..<12).map { i in
            CLLocationCoordinate2D(latitude: 52.3600 + offset + Double(i) * 0.0008,
                                   longitude: 4.8850 + Double(i % 4) * 0.0008)
        }
    }

    private func park(near c: CLLocationCoordinate2D, _ name: String) -> POI {
        POI(name: name, location: Location(c), category: .park, googlePlaceId: "mapkit:\(name)")
    }

    func testFailedSightSearchIsReportedAndNotCached() async {
        let discovery = StubDiscovery(outcome: .failure(POIError.searchUnavailable))
        let aggregator = POIAggregatorService(discovery: discovery, enrichment: StubEnrichment())
        for _ in 0..<2 {
            do {
                _ = try await aggregator.fetchPOIs(nearPolyline: loop(), maxDistance: 500, limit: 20)
                XCTFail("Expected searchUnavailable")
            } catch {
                XCTAssertEqual(error as? POIError, .searchUnavailable)
            }
        }
        let calls = await discovery.calls
        XCTAssertEqual(calls, 2, "A failure must not be cached: Try again has to search again")
    }

    func testNoSightsIsAnEmptyListNotAnError() async throws {
        let aggregator = POIAggregatorService(discovery: StubDiscovery(outcome: .success([])), enrichment: StubEnrichment())
        let pois = try await aggregator.fetchPOIs(nearPolyline: loop(), maxDistance: 500, limit: 20)
        XCTAssertTrue(pois.isEmpty)
    }

    func testReopeningALoopUsesItsCachedSights() async throws {
        let path = loop()
        let discovery = StubDiscovery(outcome: .success([park(near: path[3], "Vondelpark")]))
        let aggregator = POIAggregatorService(discovery: discovery, enrichment: StubEnrichment())
        let first = try await aggregator.fetchPOIs(nearPolyline: path, maxDistance: 500, limit: 20)
        let second = try await aggregator.fetchPOIs(nearPolyline: path, maxDistance: 500, limit: 20)
        XCTAssertEqual(first.map(\.name), ["Vondelpark"])
        XCTAssertEqual(second.map(\.name), first.map(\.name))
        let calls = await discovery.calls
        XCTAssertEqual(calls, 1)
    }

    func testTwoNearbyLoopsDoNotShareCachedSights() {
        // Middle points ~100 m apart: the old key (centre rounded to 0.01°)
        // gave both loops the same cached list.
        let a = POIAggregatorService.cacheKey(for: loop())
        let b = POIAggregatorService.cacheKey(for: loop(offset: 0.0009))
        XCTAssertNotNil(a)
        XCTAssertNotEqual(a, b)
    }

    func testFirstPassSightsArePassedOnWhileRetrying() async throws {
        let path = loop()
        let early = [park(near: path[2], "Sarphatipark")]
        let all = early + [park(near: path[8], "Oosterpark")]
        let discovery = StubDiscovery(outcome: .success(all), partial: early)
        let aggregator = POIAggregatorService(discovery: discovery, enrichment: StubEnrichment())
        let received = Received()
        let final = try await aggregator.fetchPOIs(
            nearPolyline: path, maxDistance: 500, limit: 20,
            onPartialResults: { await received.add($0) }
        )
        let partials = await received.lists
        XCTAssertEqual(partials.map { $0.map(\.name) }, [["Sarphatipark"]])
        XCTAssertEqual(Set(final.map(\.name)), ["Sarphatipark", "Oosterpark"])
    }

    func testThrottleRetriesWaitLongEnoughForMapKitToRecover() {
        // MapKit's search limit is per time window; retries spread over
        // ~26 s, each pause longer than the last.
        let delays = AppleMapKitDiscoveryService.throttleRetryDelaysSeconds
        XCTAssertEqual(delays, delays.sorted())
        XCTAssertGreaterThanOrEqual(delays.reduce(0, +), 20)
    }
}

// MARK: - Sight search stubs

private actor StubDiscovery: POIDiscovering {
    let outcome: Result<[POI], POIError>
    let partial: [POI]?
    private(set) var calls = 0

    init(outcome: Result<[POI], POIError>, partial: [POI]? = nil) {
        self.outcome = outcome
        self.partial = partial
    }

    func discoverPOIs(alongRoute polyline: [CLLocationCoordinate2D], searchIntervalMeters: Double, searchRadiusMeters: Double) async throws -> [POI] {
        try await discoverPOIs(alongRoute: polyline, searchIntervalMeters: searchIntervalMeters,
                               searchRadiusMeters: searchRadiusMeters, onPartialResults: nil)
    }

    func discoverPOIs(alongRoute polyline: [CLLocationCoordinate2D], searchIntervalMeters: Double, searchRadiusMeters: Double,
                      onPartialResults: (@Sendable ([POI]) async -> Void)?) async throws -> [POI] {
        calls += 1
        if let partial, let onPartialResults { await onPartialResults(partial) }
        return try outcome.get()
    }
}

private struct StubEnrichment: POIEnriching {
    func enrich(poi: POI, minRating: Double?) async -> POI? { poi }
}

private actor Received {
    private(set) var lists: [[POI]] = []
    func add(_ pois: [POI]) { lists.append(pois) }
}
