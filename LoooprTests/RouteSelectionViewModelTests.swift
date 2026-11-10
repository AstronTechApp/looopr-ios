import XCTest
import Combine
import CoreLocation
@testable import Looopr

/// What the route list does when a search comes back with nothing. The
/// three outcomes must stay distinct: found routes (upgrade card allowed),
/// failed/empty (retry + longer walk, never a paywall), and cancelled
/// (the user left — report nothing).
@MainActor
final class RouteSelectionViewModelTests: XCTestCase {

    private let amsterdam = CustomRouteLocation(latitude: 52.37, longitude: 4.89, displayName: "Amsterdam")

    // MARK: - Test doubles

    /// Plays back a scripted stream: yields `routes`, then finishes with
    /// `error` (or cleanly). `hang` keeps the stream open until cancelled,
    /// which is what the Mapbox service does when its task is cancelled —
    /// it finishes quietly, without throwing.
    private final class ScriptedRouteService: RouteGenerating, @unchecked Sendable {
        var routes: [Route] = []
        var error: Error?
        var hang = false
        private(set) var streamCalls = 0

        func generateLoopRoutes(start: CLLocationCoordinate2D, minutes: Int, walkingSpeedKmH: Double) async throws -> [Route] {
            if let error { throw error }
            return routes
        }

        func generateLoopRoutesStream(start: CLLocationCoordinate2D, minutes: Int, maxRoutes: Int,
                                      walkingSpeedKmH: Double) -> AsyncThrowingStream<Route, Error> {
            streamCalls += 1
            let routes = routes, error = error, hang = hang
            return AsyncThrowingStream { continuation in
                let task = Task {
                    for route in routes { continuation.yield(route) }
                    if hang {
                        // Wait until cancelled, then end like Mapbox does.
                        while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(10)) }
                        continuation.finish()
                        return
                    }
                    if let error { continuation.finish(throwing: error) } else { continuation.finish() }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        func cancelInFlightRequests() async {}
    }

    private struct FreeTier: SubscriptionProviding { let isPaidSubscriber = false }

    private final class RecordingAnalytics: AnalyticsTracking, @unchecked Sendable {
        private(set) var events: [AnalyticsEvent] = []
        func track(_ event: AnalyticsEvent) { events.append(event) }
        var names: [String] { events.map(\.name) }
    }

    private final class NoLocation: LocationProviding, @unchecked Sendable {
        var currentCoordinate: CLLocationCoordinate2D? { nil }
        var currentLocation: CLLocation? { nil }
        var currentHeading: CLLocationDirection? { nil }
        var status: CLAuthorizationStatus = .denied
        var authorizationStatus: CLAuthorizationStatus { status }
        var isAuthorized: Bool { false }
        var coordinatePublisher: AnyPublisher<CLLocationCoordinate2D, Never> { Empty().eraseToAnyPublisher() }
        var locationPublisher: AnyPublisher<CLLocation, Never> { Empty().eraseToAnyPublisher() }
        var headingPublisher: AnyPublisher<CLLocationDirection, Never> { Empty().eraseToAnyPublisher() }
        var authorizationPublisher: AnyPublisher<CLAuthorizationStatus, Never> { Empty().eraseToAnyPublisher() }
        func requestAuthorization() {}
        func startUpdating() {}
        func stopUpdating() {}
    }

    private func makeRoute(_ minutes: Int) -> Route {
        Route(name: "Loop \(minutes)", durationMinutes: minutes, distanceKilometers: Double(minutes) / 12,
              startLocation: Location(latitude: 52.37, longitude: 4.89))
    }

    private func makeViewModel(minutes: Int = 30,
                               service: ScriptedRouteService,
                               analytics: RecordingAnalytics,
                               location: CustomRouteLocation? = nil,
                               locationService: NoLocation = NoLocation()) -> RouteSelectionViewModel {
        RouteSelectionViewModel(
            walkDurationMinutes: minutes,
            customLocation: location,
            routeGeneration: service,
            mapboxGeneration: nil,
            subscriptionService: FreeTier(),
            locationService: locationService,
            analytics: analytics
        )
    }

    // MARK: - Found

    func testRoutesFoundAllowsUpgradeCard() async {
        let service = ScriptedRouteService()
        service.routes = [makeRoute(31), makeRoute(28)]
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)

        await vm.loadRoutes()

        XCTAssertEqual(vm.routes.map(\.durationMinutes), [28, 31])
        XCTAssertNil(vm.failure)
        XCTAssertTrue(vm.didFindRoutes)
        XCTAssertTrue(vm.isFreeTier)
        XCTAssertEqual(analytics.names, ["route_search_started", "route_generated"])
    }

    // MARK: - Empty / failed

    func testEmptyStreamIsAFailureNotASalesMoment() async {
        let service = ScriptedRouteService() // yields nothing, finishes cleanly
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)

        await vm.loadRoutes()

        XCTAssertTrue(vm.routes.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.failure, .noRoutes)
        XCTAssertFalse(vm.didFindRoutes, "no upgrade card after an empty search")
        XCTAssertEqual(analytics.names, ["route_search_started", "route_generated", "route_search_failed"])
        if case .routeSearchFailed(let minutes, let reason, _, _, _) = analytics.events.last! {
            XCTAssertEqual(minutes, 30)
            XCTAssertEqual(reason, "no_routes")
        } else {
            XCTFail("expected route_search_failed")
        }
    }

    func testNoRoutesFoundErrorIsReportedAsNoRoutes() async {
        let service = ScriptedRouteService()
        service.error = RouteError.noRoutesFound
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)

        await vm.loadRoutes()

        XCTAssertEqual(vm.failure, .noRoutes)
        XCTAssertFalse(vm.didFindRoutes)
        XCTAssertEqual(analytics.names, ["route_search_started", "route_search_failed"])
    }

    private static func number(_ value: AnalyticsValue?) -> Double? {
        if case .double(let d)? = value { return d }
        return nil
    }

    private static func text(_ value: AnalyticsValue?) -> String? {
        if case .string(let t)? = value { return t }
        return nil
    }

    func testNoUsableRoutesReportsDetailAndCoarseLocation() async {
        let service = ScriptedRouteService()
        service.error = RouteError.noUsableRoutes(detail: "http_422_NoSegment:8")
        let analytics = RecordingAnalytics()
        let precise = CustomRouteLocation(latitude: 52.374_031, longitude: 4.889_694, displayName: "Dam")
        let vm = makeViewModel(service: service, analytics: analytics, location: precise)

        await vm.loadRoutes()

        XCTAssertEqual(vm.failure, .noRoutes)
        XCTAssertEqual(analytics.names, ["route_search_started", "route_search_failed"])
        let started = analytics.events.first!.properties
        XCTAssertEqual(Self.number(started["lat"]), 52.37)
        XCTAssertEqual(Self.number(started["lon"]), 4.89)
        let failed = analytics.events.last!.properties
        XCTAssertEqual(Self.text(failed["reason"]), "no_routes")
        XCTAssertEqual(Self.text(failed["detail"]), "http_422_NoSegment:8")
        XCTAssertEqual(Self.number(failed["lat"]), 52.37, "never more precise than ~1 km")
        XCTAssertEqual(Self.number(failed["lon"]), 4.89)
    }

    func testLocationFailureHasNoCoordinates() async {
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: ScriptedRouteService(), analytics: analytics)
        vm.locationWaitSeconds = 0.5

        await vm.loadRoutes()

        XCTAssertNil(analytics.events.last!.properties["lat"])
        XCTAssertNil(analytics.events.last!.properties["detail"])
    }

    func testLoopsOfTheAskedLengthShowNoClosestNotice() async {
        let service = ScriptedRouteService()
        service.routes = [makeRoute(28), makeRoute(43)]
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)

        await vm.loadRoutes()

        XCTAssertFalse(vm.isShowingClosestMatches)
        if case .routeGenerated(_, _, _, _, _, let closestOnly, _) = analytics.events.last! {
            XCTAssertFalse(closestOnly)
        } else { XCTFail("expected route_generated") }
    }

    /// Sparse/hilly areas (App Review, 1 Nov): only a 55-min loop exists
    /// for a 30-min ask. Show it, say so, and keep it a success.
    func testOnlyFarOffLoopsAreFlaggedAsClosestMatches() async {
        let service = ScriptedRouteService()
        service.routes = [makeRoute(55), makeRoute(70)]
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)

        await vm.loadRoutes()

        XCTAssertTrue(vm.isShowingClosestMatches)
        XCTAssertNil(vm.failure)
        XCTAssertTrue(vm.didFindRoutes)
        if case .routeGenerated(let count, _, _, _, _, let closestOnly, _) = analytics.events.last! {
            XCTAssertEqual(count, 2)
            XCTAssertTrue(closestOnly)
        } else { XCTFail("expected route_generated") }
    }

    func testGenerationErrorIsReportedAsGenerationFailure() async {
        let service = ScriptedRouteService()
        service.error = RouteError.generationFailed("mapbox 500")
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)

        await vm.loadRoutes()

        guard case .generation = vm.failure else { return XCTFail("expected generation failure, got \(String(describing: vm.failure))") }
        XCTAssertFalse(vm.didFindRoutes)
        XCTAssertEqual(analytics.names.last, "route_search_failed")
    }

    func testPartialResultThenErrorKeepsNothing() async {
        // One route streamed in, then the generator blew up: the list must
        // not sit there half-filled with an upgrade card underneath.
        let service = ScriptedRouteService()
        service.routes = [makeRoute(30)]
        service.error = RouteError.generationFailed("timeout")
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)

        await vm.loadRoutes()

        XCTAssertTrue(vm.routes.isEmpty)
        XCTAssertNotNil(vm.failure)
        XCTAssertFalse(vm.didFindRoutes)
    }

    func testLongerWalkSuggestionStepsUpFifteenMinutesUntilTheTop() {
        let service = ScriptedRouteService()
        let analytics = RecordingAnalytics()
        XCTAssertEqual(makeViewModel(minutes: 30, service: service, analytics: analytics).suggestedLongerMinutes, 45)
        XCTAssertEqual(makeViewModel(minutes: 165, service: service, analytics: analytics).suggestedLongerMinutes, 180)
        XCTAssertNil(makeViewModel(minutes: 180, service: service, analytics: analytics).suggestedLongerMinutes)
    }

    func testRetryClearsTheFailure() async {
        let service = ScriptedRouteService()
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)
        await vm.loadRoutes()
        XCTAssertEqual(vm.failure, .noRoutes)

        service.routes = [makeRoute(30)]
        await vm.loadRoutes()
        XCTAssertNil(vm.failure)
        XCTAssertTrue(vm.didFindRoutes)
        XCTAssertEqual(service.streamCalls, 2)
    }

    // MARK: - Cancelled

    func testCancelledSearchReportsNothing() async {
        // The view was torn down mid-search (tab switch, back). The Mapbox
        // stream then ends cleanly with whatever it had — which used to be
        // logged as "0 routes" and shown as "No routes found".
        let service = ScriptedRouteService()
        service.hang = true
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)

        let search = Task { await vm.loadRoutes() }
        try? await Task.sleep(for: .milliseconds(50))
        search.cancel()
        await search.value

        XCTAssertNil(vm.failure)
        XCTAssertTrue(vm.isLoading, "state is left alone; nobody is looking")
        XCTAssertEqual(analytics.names, ["route_search_started"],
                       "no route_generated / route_search_failed for a cancelled search")
    }

    // MARK: - No location

    func testLocationTimeoutIsAFailureWithItsOwnReason() async {
        let service = ScriptedRouteService()
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: nil)
        vm.locationWaitSeconds = 0.5

        await vm.loadRoutes()

        XCTAssertEqual(vm.failure, .locationUnavailable)
        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(service.streamCalls, 0, "no generator call without a start point")
        XCTAssertEqual(analytics.names, ["route_search_started", "route_search_failed"])
        if case .routeSearchFailed(_, let reason, _, _, _) = analytics.events.last! {
            XCTAssertEqual(reason, "location_denied", "Location switched off is reported apart from no GPS fix")
        }
        XCTAssertTrue(vm.isLocationPermissionDenied, "the failure screen offers Settings + a starting point")
    }

    func testNoGPSFixWithPermissionIsLocationUnavailable() async {
        let service = ScriptedRouteService()
        let analytics = RecordingAnalytics()
        let location = NoLocation()
        location.status = .authorizedWhenInUse
        let vm = makeViewModel(service: service, analytics: analytics, location: nil, locationService: location)
        vm.locationWaitSeconds = 0.5

        await vm.loadRoutes()

        XCTAssertEqual(vm.failure, .locationUnavailable)
        XCTAssertFalse(vm.isLocationPermissionDenied)
        if case .routeSearchFailed(_, let reason, _, _, _) = analytics.events.last! {
            XCTAssertEqual(reason, "location_unavailable")
        } else {
            XCTFail("expected route_search_failed")
        }
    }

    // MARK: - Slow searches (1.3)

    func testNoRouteBeforeTheTimeLimitIsATimeout() async {
        // The generator never yields: the user gets the retry screen and a
        // route_search_failed with reason "timeout", instead of skeletons
        // forever and no event at all.
        let service = ScriptedRouteService()
        service.hang = true
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)
        vm.slowHintSeconds = 0.1
        vm.firstRouteTimeoutSeconds = 0.4
        vm.searchCapSeconds = 5

        let search = Task { await vm.loadRoutes() }
        try? await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(vm.isTakingLong, "the waiting hint shows before the time limit")
        await search.value

        XCTAssertEqual(vm.failure, .timeout)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isTakingLong)
        XCTAssertEqual(analytics.names, ["route_search_started", "route_search_failed"])
        if case .routeSearchFailed(_, let reason, _, _, _) = analytics.events.last! {
            XCTAssertEqual(reason, "timeout")
        } else {
            XCTFail("expected route_search_failed")
        }
    }

    func testSlowSearchIsCappedAndKeepsWhatItFound() async {
        let service = ScriptedRouteService()
        service.routes = [makeRoute(29)]
        service.hang = true
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)
        vm.slowHintSeconds = 0.1
        vm.firstRouteTimeoutSeconds = 0.2
        vm.searchCapSeconds = 0.5

        await vm.loadRoutes()

        XCTAssertEqual(vm.routes.count, 1)
        XCTAssertNil(vm.failure)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isTakingLong, "a route arrived, so no waiting hint")
        XCTAssertEqual(analytics.names, ["route_search_started", "route_generated"])
        if case .routeGenerated(let count, _, let first, let total, let stoppedEarly, _, _) = analytics.events.last! {
            XCTAssertEqual(count, 1)
            XCTAssertNotNil(first)
            XCTAssertGreaterThanOrEqual(total, 0.4)
            XCTAssertTrue(stoppedEarly)
        } else {
            XCTFail("expected route_generated")
        }
    }

    func testOverlappingSearchesRunOnce() async {
        // A quick double tap must not start a second (paid) search.
        let service = ScriptedRouteService()
        service.routes = [makeRoute(30)]
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)

        async let first: Void = vm.loadRoutes()
        async let second: Void = vm.loadRoutes()
        _ = await (first, second)

        XCTAssertEqual(service.streamCalls, 1)
        XCTAssertEqual(analytics.names.filter { $0 == "route_search_started" }.count, 1)
    }
    // MARK: - 1.5: locked previews and the first-search paywall

    /// The generator sends the closest fits first; a free user opens those
    /// two and sees the other three as locked loops.
    func testFreeTierOpensTwoAndLocksTheRest() async {
        let service = ScriptedRouteService()
        service.routes = [makeRoute(29), makeRoute(33), makeRoute(24), makeRoute(40), makeRoute(21)]
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(service: service, analytics: analytics, location: amsterdam)

        await vm.loadRoutes()

        XCTAssertEqual(vm.routes.map(\.durationMinutes), [29, 33])
        XCTAssertEqual(vm.lockedRoutes.map(\.durationMinutes), [21, 24, 40])
        guard case .routeGenerated(let count, _, _, _, _, _, let locked) = analytics.events.last! else {
            return XCTFail("expected route_generated")
        }
        XCTAssertEqual(count, 5)
        XCTAssertEqual(locked, 3)
    }

    func testFirstSearchPaywallIsOfferedOnceAndOnlyAfterLoops() async {
        let suite = "paywall-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let empty = makeViewModel(service: ScriptedRouteService(), analytics: RecordingAnalytics(), location: amsterdam)
        await empty.loadRoutes()
        XCTAssertFalse(empty.takeFirstSearchPaywall(defaults: defaults), "a failed search is not a sales moment")

        let service = ScriptedRouteService()
        service.routes = [makeRoute(30)]
        let vm = makeViewModel(service: service, analytics: RecordingAnalytics(), location: amsterdam)
        await vm.loadRoutes()
        XCTAssertTrue(vm.takeFirstSearchPaywall(defaults: defaults))
        XCTAssertFalse(vm.takeFirstSearchPaywall(defaults: defaults), "only once per install")
    }

    func testClosingThePaywallWithoutBuyingIsADismissal() {
        let analytics = RecordingAnalytics()
        let paywall = PaywallViewModel(source: .lockedRoute, analytics: analytics)
        paywall.trackShown()
        paywall.trackClosed()
        paywall.trackClosed() // onDisappear can fire twice; count it once
        XCTAssertEqual(analytics.names, ["paywall_shown", "paywall_dismissed"])
        guard case .paywallDismissed(let source) = analytics.events.last! else { return XCTFail() }
        XCTAssertEqual(source, "locked_route")
    }
}

/// Navigation guards added in 1.3: a double tap must not stack the same
/// screen twice, and a swipe-back must keep the router's own list in step.
@MainActor
final class AppRouterNavigationTests: XCTestCase {

    func testSameScreenTwiceIsPushedOnce() {
        let router = AppRouter()
        router.navigate(to: .routeSelection(walkMinutes: 30))
        router.navigate(to: .routeSelection(walkMinutes: 30))
        XCTAssertEqual(router.routeStack.count, 1)
        XCTAssertEqual(router.path.count, 1)
    }

    func testSwipeBackTrimsTheStackSoTheSameSearchCanOpenAgain() {
        let router = AppRouter()
        router.navigate(to: .routeSelection(walkMinutes: 30))
        // What NavigationStack does on a swipe-back: it shortens `path`.
        router.path.removeLast()
        XCTAssertTrue(router.routeStack.isEmpty)

        router.navigate(to: .routeSelection(walkMinutes: 30))
        XCTAssertEqual(router.routeStack.count, 1, "the same search can be opened again")
    }

    func testPopRemovesExactlyOneScreen() {
        let router = AppRouter()
        router.navigate(to: .routeSelection(walkMinutes: 30))
        router.navigate(to: .settings)
        router.pop()
        XCTAssertEqual(router.routeStack.count, 1)
        XCTAssertEqual(router.path.count, 1)
    }
}

// MARK: - Mapbox generator with canned responses

/// Answers every Mapbox request with one canned response.
private final class CannedMapbox: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "api.mapbox.com" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class MapboxGenerationFailureTests: XCTestCase {
    override func setUp() { URLProtocol.registerClass(CannedMapbox.self) }
    override func tearDown() { URLProtocol.unregisterClass(CannedMapbox.self) }

    private func run(lat: Double) async -> Error? {
        let service = MapboxRouteGenerationService(accessToken: "test")
        do {
            _ = try await service.generateLoopRoutes(
                start: CLLocationCoordinate2D(latitude: lat, longitude: 4.89), minutes: 30, walkingSpeedKmH: 5)
            return nil
        } catch { return error }
    }

    /// LOOOPR-IOS-5: a zero-length route made the radius infinite and
    /// trapped in Int(currentRadius). Now it's just an unusable candidate.
    func testZeroLengthAnswerDoesNotCrash() async {
        CannedMapbox.status = 200
        CannedMapbox.body = Data(#"{"code":"Ok","routes":[{"distance":0,"duration":0,"geometry":{"coordinates":[[4.89,52.37]]},"legs":[]}]}"#.utf8)
        let error = await run(lat: 52.371)
        XCTAssertEqual(error as? RouteError, .noUsableRoutes(detail: "empty_route:8"))
    }

    func testNoSegmentIsNamedInTheDetail() async {
        CannedMapbox.status = 422
        CannedMapbox.body = Data(#"{"code":"NoSegment","message":"Could not find a matching segment"}"#.utf8)
        let error = await run(lat: 52.372)
        XCTAssertEqual(error as? RouteError, .noUsableRoutes(detail: "http_422_NoSegment:8"))
    }

    /// A clean loop (a circle, 4 km) that is too long for the ask on every
    /// attempt used to end in "no routes"; now it comes back as the
    /// closest match.
    private func circleRoute(durationSeconds: Double) -> Data {
        let center = CLLocationCoordinate2D(latitude: 52.37, longitude: 4.89)
        let points = (0...400).map { i -> [Double] in
            let c = center.coordinate(at: 637, bearing: Double(i) * 360 / 400)
            return [c.longitude, c.latitude]
        }
        let legs = (0..<5).map { _ in ["distance": 800.0, "duration": durationSeconds / 5, "steps": [] as [Any]] as [String: Any] }
        let body: [String: Any] = ["code": "Ok", "routes": [[
            "distance": 4000.0, "duration": durationSeconds,
            "geometry": ["coordinates": points], "legs": legs
        ]]]
        return try! JSONSerialization.data(withJSONObject: body)
    }

    func testTooLongEverywhereReturnsTheClosestLoop() async throws {
        CannedMapbox.status = 200
        CannedMapbox.body = circleRoute(durationSeconds: 55 * 60)
        let service = MapboxRouteGenerationService(accessToken: "test")
        let routes = try await service.generateLoopRoutes(
            start: CLLocationCoordinate2D(latitude: 52.374, longitude: 4.89), minutes: 30, walkingSpeedKmH: 5)
        XCTAssertEqual(routes.map(\.durationMinutes), [55])
    }

    func testFarTooLongIsStillNoRoutes() async {
        CannedMapbox.status = 200
        CannedMapbox.body = circleRoute(durationSeconds: 120 * 60) // 4x a 30-min ask
        let error = await run(lat: 52.375)
        XCTAssertEqual(error as? RouteError, .noUsableRoutes(detail: "too_long:8"))
    }

    func testOkWithoutRoutesIsNoRoute() async {
        CannedMapbox.status = 200
        CannedMapbox.body = Data(#"{"code":"NoRoute","routes":[]}"#.utf8)
        let error = await run(lat: 52.373)
        XCTAssertEqual(error as? RouteError, .noUsableRoutes(detail: "no_route_NoRoute:8"))
    }
}
