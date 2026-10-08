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
        var authorizationStatus: CLAuthorizationStatus { .denied }
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
                               location: CustomRouteLocation? = nil) -> RouteSelectionViewModel {
        RouteSelectionViewModel(
            walkDurationMinutes: minutes,
            customLocation: location,
            routeGeneration: service,
            mapboxGeneration: nil,
            subscriptionService: FreeTier(),
            locationService: NoLocation(),
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
        if case .routeSearchFailed(let minutes, let reason) = analytics.events.last! {
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
        if case .routeSearchFailed(_, let reason) = analytics.events.last! {
            XCTAssertEqual(reason, "location_unavailable")
        }
    }
}
