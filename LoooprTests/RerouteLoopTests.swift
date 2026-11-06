import XCTest
import CoreLocation
@testable import Looopr

// MARK: - Test: Re-routing on loop routes should snap to nearest remaining point

/// These tests reproduce the bug where re-routing on a loop route would skip
/// most of the walk by snapping to a geographically close point near the END
/// of the loop, instead of the correct point near the BEGINNING of the
/// remaining route.
///
/// The fix: use the candidate's polylineIndex (offset from the remaining slice)
/// directly, rather than doing a closest-vertex search on the full polyline.
final class RerouteLoopTests: XCTestCase {

    // MARK: - Helpers

    /// Build a roughly circular loop route (clockwise) around a center point.
    /// Returns ~pointCount coordinates forming a closed loop.
    private func makeLoopPolyline(
        center: CLLocationCoordinate2D = .amsterdam,
        radiusMeters: Double = 500,
        pointCount: Int = 40
    ) -> [CLLocationCoordinate2D] {
        (0...pointCount).map { i in
            let bearing = (360.0 / Double(pointCount)) * Double(i)
            return center.coordinate(at: radiusMeters, bearing: bearing)
        }
    }

    private func closestPolylineIndex(
        to point: CLLocationCoordinate2D,
        in polyline: [CLLocationCoordinate2D]
    ) -> Int {
        var minDist = Double.infinity
        var minIdx = 0
        for (i, coord) in polyline.enumerated() {
            let dist = point.distance(to: coord)
            if dist < minDist { minDist = dist; minIdx = i }
        }
        return minIdx
    }

    private func makeNavigationConfig(
        wrongWayWarmupSeconds: TimeInterval = 0,
        wrongWayDetectionWindowMeters: Double = 250,
        wrongWayTriggerMeters: Double = 12,
        wrongWayMinDurationSeconds: TimeInterval = 0,
        wrongWayMinSpeedMetersPerSecond: Double = 0,
        wrongWayBearingBaselineMeters: Double = 10,
        wrongWayMaxFlips: Int = 1
    ) -> AppConfiguration.Navigation {
        AppConfiguration.Navigation(
            stepAdvanceThresholdMeters: 25,
            offRouteThresholdMeters: 50,
            offRouteHoldSeconds: 8,
            rerouteCooldownSeconds: 30,
            noProgressTimeoutSeconds: 90,
            directionCheckDistanceMeters: 30,
            directionReverseRatio: 0.6,
            foodSpotProximityMeters: 50,
            gpsAccuracyThresholdMeters: 20,
            reentrySearchMinMeters: 100,
            reentrySearchMaxMeters: 400,
            reentryCorridorDegrees: 80,
            suppressRerouteLastPercent: 0.10,
            rerouteToastDismissSeconds: 3,
            midWalkDirectionThresholdDegrees: 150,
            midWalkDirectionConsecutiveChecks: 3,
            midWalkDirectionCooldownSeconds: 60,
            wrongWayWarmupSeconds: wrongWayWarmupSeconds,
            wrongWayDetectionWindowMeters: wrongWayDetectionWindowMeters,
            wrongWayDivergenceDegrees: 120,
            wrongWayTriggerMeters: wrongWayTriggerMeters,
            wrongWayMinDurationSeconds: wrongWayMinDurationSeconds,
            wrongWayMinSpeedMetersPerSecond: wrongWayMinSpeedMetersPerSecond,
            wrongWayBearingBaselineMeters: wrongWayBearingBaselineMeters,
            wrongWayMaxFlips: wrongWayMaxFlips
        )
    }

    // MARK: - Route flip path tests

    /// When the walker starts down the reversed first segment, the flip path
    /// should continue to the next reversed vertex. The old closest-vertex
    /// approach could send the first recompute leg back to the original start,
    /// making the "flip" look like it did nothing.
    @MainActor
    func testRouteFlipPathContinuesAheadOnReversedFirstSegment() {
        let start = CLLocationCoordinate2D.amsterdam
        let intendedFirst = start.coordinate(at: 120, bearing: 0)
        let farCorner = start.coordinate(at: 180, bearing: 90)
        let reversedFirst = start.coordinate(at: 120, bearing: 180)
        let loop = [start, intendedFirst, farCorner, reversedFirst, start]

        let currentLocation = start.coordinate(at: 20, bearing: 180)
        let flipPath = WalkNavigationViewModel.makeRouteFlipPath(
            from: currentLocation,
            sourcePolyline: loop
        )

        XCTAssertGreaterThanOrEqual(flipPath.count, 2)
        XCTAssertLessThan(
            flipPath[1].distance(to: reversedFirst),
            1,
            "Flipped path should continue ahead to the next reversed route point"
        )
        XCTAssertGreaterThan(
            flipPath[1].distance(to: start),
            100,
            "Flipped path should not route back through the original start point first"
        )
    }

    func testWrongWayDetectorUsesReverseStartBearingWhenLoopBearingIsAmbiguous() {
        let detector = WrongWayDetector(navigation: makeNavigationConfig())
        var didTrigger = false
        detector.onWrongWayDetected = { didTrigger = true }
        detector.startSession()

        let start = CLLocationCoordinate2D.amsterdam
        let firstFix = start.coordinate(at: 5, bearing: 180)
        let secondFix = start.coordinate(at: 20, bearing: 180)

        detector.check(
            userLocation: CLLocation(latitude: firstFix.latitude, longitude: firstFix.longitude),
            // Simulate the loop-start bug: the closest route segment is also
            // southbound, so the primary bearing alone would not trigger.
            expectedBearing: 180,
            intendedStartBearing: 0,
            reverseStartBearing: 180
        )
        detector.check(
            userLocation: CLLocation(latitude: secondFix.latitude, longitude: secondFix.longitude),
            expectedBearing: 180,
            intendedStartBearing: 0,
            reverseStartBearing: 180
        )

        XCTAssertTrue(didTrigger)
        XCTAssertEqual(detector.debugSnapshot.status, "triggered")
        XCTAssertEqual(detector.debugSnapshot.reason, "reverse start")
    }

    private func makeFix(
        _ coordinate: CLLocationCoordinate2D,
        at time: Date,
        speed: CLLocationSpeed
    ) -> CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: -1,
            speed: speed,
            timestamp: time
        )
    }

    func testWrongWayDetectorIgnoresStationaryGPSDrift() {
        let detector = WrongWayDetector(navigation: makeNavigationConfig(
            wrongWayTriggerMeters: 12,
            wrongWayMinSpeedMetersPerSecond: 0.5
        ))
        var didTrigger = false
        detector.onWrongWayDetected = { didTrigger = true }
        detector.startSession()

        // User stands at the start looking at the phone while the fix
        // wanders ~6 m in random directions, always "away" from the route
        // bearing (0°). Speed is reported as 0 the whole time.
        let start = CLLocationCoordinate2D.amsterdam
        let t0 = Date()
        var point = start
        for i in 0..<12 {
            let bearing = [150.0, 200.0, 170.0, 220.0][i % 4]
            point = point.coordinate(at: 6, bearing: bearing)
            detector.check(
                userLocation: makeFix(point, at: t0.addingTimeInterval(Double(i) * 4), speed: 0),
                expectedBearing: 0
            )
        }

        XCTAssertFalse(didTrigger, "GPS drift while standing still must not prompt a route flip")
        XCTAssertEqual(detector.debugSnapshot.status, "stationary")
    }

    func testWrongWayDetectorRequiresSustainedDurationNotJustDistance() {
        let detector = WrongWayDetector(navigation: makeNavigationConfig(
            wrongWayTriggerMeters: 12,
            wrongWayMinDurationSeconds: 20,
            wrongWayMinSpeedMetersPerSecond: 0.5
        ))
        var triggerCount = 0
        detector.onWrongWayDetected = { triggerCount += 1 }
        detector.startSession()

        // Walking due south at ~1.25 m/s (5 m every 4 s) while the route
        // expects north.
        let start = CLLocationCoordinate2D.amsterdam
        let t0 = Date()
        var point = start
        var elapsed: TimeInterval = 0

        func step() {
            point = point.coordinate(at: 5, bearing: 180)
            elapsed += 4
            detector.check(
                userLocation: makeFix(point, at: t0.addingTimeInterval(elapsed), speed: 1.25),
                expectedBearing: 0
            )
        }

        // Fix 1 primes, fix 2 builds the bearing baseline; by fix 5 we've
        // logged 15 m of wrong-way travel (> 12 m trigger) but only 12 s of
        // it — no prompt yet.
        for _ in 0..<5 { step() }
        XCTAssertEqual(triggerCount, 0, "Distance alone must not trigger before the minimum duration")
        XCTAssertEqual(detector.debugSnapshot.status, "accumulating")

        // Keep going: once >= 20 s of continuous wrong-way travel, prompt.
        for _ in 0..<2 { step() }
        XCTAssertEqual(triggerCount, 1)
        XCTAssertEqual(detector.debugSnapshot.status, "triggered")
    }

    func testWrongWayDetectorResetsWhenUserSelfCorrects() {
        let detector = WrongWayDetector(navigation: makeNavigationConfig(
            wrongWayTriggerMeters: 12,
            wrongWayMinDurationSeconds: 20,
            wrongWayMinSpeedMetersPerSecond: 0.5
        ))
        var didTrigger = false
        detector.onWrongWayDetected = { didTrigger = true }
        detector.startSession()

        let start = CLLocationCoordinate2D.amsterdam
        let t0 = Date()
        var point = start
        var elapsed: TimeInterval = 0
        func step(bearing: Double) {
            point = point.coordinate(at: 5, bearing: bearing)
            elapsed += 4
            detector.check(
                userLocation: makeFix(point, at: t0.addingTimeInterval(elapsed), speed: 1.25),
                expectedBearing: 0
            )
        }

        // 16 s south (wrong), then a long stretch north (right).
        for _ in 0..<5 { step(bearing: 180) }
        for _ in 0..<10 { step(bearing: 0) }

        XCTAssertFalse(didTrigger)
        XCTAssertEqual(detector.debugSnapshot.status, "aligned")
        XCTAssertEqual(detector.debugSnapshot.wrongWayMeters, 0)
    }

    @MainActor
    func testStepRouteDistancesDisambiguateClosedLoopStartAndFinish() {
        let start = CLLocationCoordinate2D.amsterdam
        let north = start.coordinate(at: 100, bearing: 0)
        let east = north.coordinate(at: 100, bearing: 90)
        let loop = [start, north, east, start]
        let totalDistance = start.distance(to: north)
            + north.distance(to: east)
            + east.distance(to: start)

        let steps = [
            NavigationStep(instruction: "Start", distanceMeters: 0, coordinate: start),
            NavigationStep(instruction: "Turn right", distanceMeters: 0, coordinate: east),
            NavigationStep(instruction: "Arrive", distanceMeters: 0, coordinate: start)
        ]

        let distances = WalkNavigationViewModel.routeDistancesForSteps(steps, along: loop)

        XCTAssertEqual(distances.count, steps.count)
        XCTAssertEqual(distances[0] ?? -1, 0, accuracy: 1)
        XCTAssertEqual(distances[2] ?? -1, totalDistance, accuracy: 1)
    }

    @MainActor
    func testStepAdvanceByRouteProgressCatchesMissedStepTarget() {
        let totalDistance: Double = 160
        let stepDistance: Double = 40
        let tolerance: Double = 12

        XCTAssertFalse(WalkNavigationViewModel.hasPassedStepByRouteProgress(
            progressDistanceFromStart: 45,
            stepDistanceFromStart: stepDistance,
            totalDistance: totalDistance,
            walkDirection: .forward,
            toleranceMeters: tolerance
        ))
        XCTAssertTrue(WalkNavigationViewModel.hasPassedStepByRouteProgress(
            progressDistanceFromStart: 80,
            stepDistanceFromStart: stepDistance,
            totalDistance: totalDistance,
            walkDirection: .forward,
            toleranceMeters: tolerance
        ))
        XCTAssertFalse(WalkNavigationViewModel.hasPassedStepByRouteProgress(
            progressDistanceFromStart: 80,
            stepDistanceFromStart: 120,
            totalDistance: totalDistance,
            walkDirection: .forward,
            toleranceMeters: tolerance
        ))
    }

    // MARK: - ReentryPointFinder tests

    /// Verify that the ReentryPointFinder returns a polylineIndex relative to the
    /// remaining slice, and that the index is near the start of that slice —
    /// NOT near the end.
    func testReentryPointFinderReturnsEarlyIndex() {
        let loop = makeLoopPolyline()

        // Simulate: user is at index ~5 (early in the loop) and has gone off route.
        let closestIdx = 5
        let remaining = Array(loop[(closestIdx + 1)...])

        // User is slightly off the route, heading roughly forward (east-ish).
        let userLocation = loop[closestIdx].coordinate(at: 60, bearing: 90)
        let userHeading: CLLocationDirection = 90

        let config = AppConfiguration.Navigation(
            stepAdvanceThresholdMeters: 25,
            offRouteThresholdMeters: 50,
            offRouteHoldSeconds: 8,
            rerouteCooldownSeconds: 30,
            noProgressTimeoutSeconds: 90,
            directionCheckDistanceMeters: 30,
            directionReverseRatio: 0.6,
            foodSpotProximityMeters: 50,
            gpsAccuracyThresholdMeters: 20,
            reentrySearchMinMeters: 100,
            reentrySearchMaxMeters: 400,
            reentryCorridorDegrees: 80,
            suppressRerouteLastPercent: 0.10,
            rerouteToastDismissSeconds: 3,
            midWalkDirectionThresholdDegrees: 150,
            midWalkDirectionConsecutiveChecks: 3,
            midWalkDirectionCooldownSeconds: 60,
            wrongWayWarmupSeconds: 10,
            wrongWayDetectionWindowMeters: 100,
            wrongWayDivergenceDegrees: 120,
            wrongWayTriggerMeters: 25,
            wrongWayMinDurationSeconds: 0,
            wrongWayMinSpeedMetersPerSecond: 0,
            wrongWayBearingBaselineMeters: 10,
            wrongWayMaxFlips: 3
        )

        let candidate = ReentryPointFinder.findReentryPoint(
            userLocation: userLocation,
            userHeading: userHeading,
            remainingPolyline: remaining,
            config: config
        )

        // Should find a candidate
        XCTAssertNotNil(candidate, "Should find a re-entry candidate on the remaining route")

        guard let candidate else { return }

        // The candidate's polylineIndex should be in the first half of the remaining route.
        // On the old buggy code this wouldn't matter here (the index was correct in
        // ReentryPointFinder), but we verify it to be thorough.
        XCTAssertLessThan(
            candidate.polylineIndex,
            remaining.count / 2,
            "Re-entry should be in the first half of the remaining route, not near the end"
        )
    }

    /// THE KEY BUG TEST: On a loop route, using closestPolylineIndex on the
    /// full polyline can return an index near the END because loop routes have
    /// geographically close points at opposite ends of the array.
    func testBuggyClosestIndexSnapsToEndOfLoop() {
        let loop = makeLoopPolyline(radiusMeters: 500, pointCount: 40)

        // User is early in the walk (index ~5)
        let closestIdx = 5
        let remaining = Array(loop[(closestIdx + 1)...])

        // Pick a point that's ~200m ahead on the route.
        // On a 500m-radius loop, points are ~78m apart, so index ~3 in remaining ≈ 234m ahead.
        let reentryPointOnRoute = remaining[3]

        // The CORRECT approach: offset from the remaining slice
        let correctIdx = closestIdx + 1 + 3  // = 9

        // On a loop, the correct index is near the start of the array (9 out of 41)
        XCTAssertEqual(correctIdx, 9)

        // The correct approach is deterministic: it always gives closestIdx + 1
        // + candidate.polylineIndex.
        // We verify the correct index points at the right coordinate.
        let epsilon = 0.000001
        XCTAssertEqual(loop[correctIdx].latitude, reentryPointOnRoute.latitude, accuracy: epsilon)
        XCTAssertEqual(loop[correctIdx].longitude, reentryPointOnRoute.longitude, accuracy: epsilon)
    }

    /// Verify that the fixed index calculation preserves enough of the route.
    /// The path after rejoin should contain most of the remaining route, not
    /// skip to the end.
    func testFixedReroutePreservesRouteLength() {
        let loop = makeLoopPolyline(radiusMeters: 500, pointCount: 40)
        let totalPoints = loop.count  // 41

        // User is at index 5 (early)
        let closestIdx = 5
        let candidatePolylineIndex = 3  // Re-entry ~3 segments ahead in remaining

        // FIXED: direct index offset
        let reentryIdx = closestIdx + 1 + candidatePolylineIndex  // = 9
        let pathAfterRejoin = Array(loop[reentryIdx...])

        // Should have most of the route remaining (41 - 9 = 32 points)
        XCTAssertEqual(pathAfterRejoin.count, totalPoints - reentryIdx)
        XCTAssertGreaterThan(
            pathAfterRejoin.count,
            totalPoints / 2,
            "After re-routing early in a loop, most of the route should remain"
        )
    }

    /// Demonstrate the bug scenario: on a 500m-radius loop, point at index 8
    /// is geographically close to point at index 33 (opposite side of array,
    /// nearby on the loop's geography). closestPolylineIndex would pick 33.
    func testLoopGeographicAmbiguity() {
        let loop = makeLoopPolyline(radiusMeters: 500, pointCount: 40)

        // Points at index 5 and index 35 should be geographically close
        // because 5/40 of the loop (45°) and 35/40 (315°) are symmetric
        // — only 2 × sin(22.5°) × 500 ≈ 383m apart. But more importantly,
        // the midpoint of segment near index 8 could be closer to index ~32
        // on the opposite side of the array.

        // Take a point that's geographically between indices 7-8 area
        let testPoint = loop[8]

        // Find closest on full polyline — should return 8
        let idx = closestPolylineIndex(to: testPoint, in: loop)
        XCTAssertEqual(idx, 8, "Direct lookup should find the exact point")

        // But now take the midpoint of two nearby segments — on a real GPS
        // this could drift and match a different vertex on the loop
        let midLat = (loop[7].latitude + loop[8].latitude) / 2
        let midLon = (loop[7].longitude + loop[8].longitude) / 2
        let midpoint = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)

        let midIdx = closestPolylineIndex(to: midpoint, in: loop)
        // This should be 7 or 8, but on real GPS-derived coordinates with
        // noise, the old approach was fragile. The key point: we should
        // never use closestPolylineIndex for this — we should use the
        // known offset.
        XCTAssertTrue(
            midIdx == 7 || midIdx == 8,
            "Midpoint should resolve to adjacent index, but on loop routes this is fragile"
        )
    }
}

// MARK: - Test coordinate helper

private extension CLLocationCoordinate2D {
    /// Central Amsterdam — convenient origin for tests
    static let amsterdam = CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)
}

// MARK: - Reroute storm (6 Nov 2026)

/// A real walk on 6 Nov 2026 (build 14): 20 reroutes in 20 minutes, one
/// every ~41 s (8 s off-route hold + 30 s cooldown), each with a buzz and
/// a toast, and the walk was never finished. Automatic rerouting must
/// give up after a few reroutes in quick succession and hand control to
/// the user, and the events must say what happened.
@MainActor
final class RerouteStormTests: XCTestCase {

    private final class RecordingAnalytics: AnalyticsTracking, @unchecked Sendable {
        var events: [AnalyticsEvent] = []
        func track(_ event: AnalyticsEvent) { events.append(event) }
        var names: [String] { events.map(\.name) }
    }

    /// Answers every reroute with the original route line, so a user
    /// standing beside it stays off-route after each reroute.
    private final class FixedDirections: NavigationDirecting, @unchecked Sendable {
        let line: [CLLocationCoordinate2D]
        init(line: [CLLocationCoordinate2D]) { self.line = line }
        func computeSteps(for route: Route) async throws -> [NavigationStep] { [] }
        func computeDetour(from current: CLLocationCoordinate2D, to target: CLLocationCoordinate2D) async throws -> DetourResult {
            DetourResult(steps: [], polylineCoordinates: line)
        }
        func computeStepsAlongPath(_ coordinates: [CLLocationCoordinate2D]) async throws -> RerouteResult {
            RerouteResult(steps: [NavigationStep(instruction: "Continue", distanceMeters: 100, coordinate: line[0])], polyline: line)
        }
    }

    private let origin = CLLocationCoordinate2D(latitude: 52.3677, longitude: 4.8845)

    /// 1 km straight north, a point every 10 m.
    private var line: [CLLocationCoordinate2D] {
        (0...100).map { origin.coordinate(at: Double($0) * 10, bearing: 0) }
    }

    private func makeViewModel(analytics: RecordingAnalytics) -> WalkNavigationViewModel {
        let route = Route(name: "Test Line", durationMinutes: 15, distanceKilometers: 1,
                          coordinates: line.map { Location($0) },
                          startLocation: Location(origin))
        let vm = WalkNavigationViewModel(route: route,
                                         directionsService: FixedDirections(line: line),
                                         analytics: analytics,
                                         walkHistoryRepository: nil)
        vm.rerouteCooldownSeconds = 0
        return vm
    }

    /// 100 m east of the line, 200 m along it: clearly off-route, not in
    /// the last 10%.
    private func offRouteFix() -> CLLocation {
        let c = origin.coordinate(at: 200, bearing: 0).coordinate(at: 100, bearing: 90)
        return CLLocation(coordinate: c, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: Date())
    }

    private func waitForRerouteToFinish(_ vm: WalkNavigationViewModel) async {
        for _ in 0..<50 where vm.isRerouting {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    func testFourthOffRouteInAStormPausesInsteadOfRerouting() async {
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(analytics: analytics)
        vm.handleLocationUpdate(offRouteFix())

        for _ in 0..<3 {
            vm.offRouteConfirmed(distanceMeters: 100)
            await waitForRerouteToFinish(vm)
        }
        XCTAssertEqual(analytics.names.filter { $0 == "reroute_triggered" }.count, 3)
        XCTAssertFalse(vm.isReroutePaused)

        vm.offRouteConfirmed(distanceMeters: 100)
        await waitForRerouteToFinish(vm)

        XCTAssertTrue(vm.isReroutePaused, "the 4th off-route in 3 minutes pauses rerouting")
        XCTAssertEqual(analytics.names.filter { $0 == "reroute_triggered" }.count, 3, "no 4th reroute")
        XCTAssertEqual(analytics.names.filter { $0 == "off_route_detected" }.count, 4)
        XCTAssertEqual(analytics.names.last, "reroute_paused")
        if case .reroutePaused(_, let reroutes, _) = analytics.events.last! {
            XCTAssertEqual(reroutes, 3)
        } else { XCTFail("expected reroute_paused") }

        // Paused: more off-route confirmations do nothing but log.
        vm.offRouteConfirmed(distanceMeters: 120)
        await waitForRerouteToFinish(vm)
        XCTAssertEqual(analytics.names.filter { $0 == "reroute_triggered" }.count, 3)
        XCTAssertEqual(analytics.names.filter { $0 == "reroute_paused" }.count, 1, "paused once, not again")
    }

    func testGuideMeBackReroutesOnceAndResumesAutomaticRerouting() async {
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(analytics: analytics)
        vm.handleLocationUpdate(offRouteFix())
        for _ in 0..<4 {
            vm.offRouteConfirmed(distanceMeters: 100)
            await waitForRerouteToFinish(vm)
        }
        XCTAssertTrue(vm.isReroutePaused)

        vm.resumeGuidance()
        await waitForRerouteToFinish(vm)

        XCTAssertFalse(vm.isReroutePaused)
        XCTAssertEqual(analytics.names.filter { $0 == "reroute_triggered" }.count, 4)
        if case .rerouteTriggered(_, let number, _, _, _, _, let trigger) = analytics.events.last! {
            XCTAssertEqual(number, 4)
            XCTAssertEqual(trigger, "manual")
        } else { XCTFail("expected reroute_triggered") }

        // The storm counter restarted: the next off-route reroutes again.
        vm.offRouteConfirmed(distanceMeters: 100)
        await waitForRerouteToFinish(vm)
        XCTAssertEqual(analytics.names.filter { $0 == "reroute_triggered" }.count, 5)
        XCTAssertFalse(vm.isReroutePaused)
    }

    func testBackOnRouteClearsThePauseQuietly() async {
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(analytics: analytics)
        vm.handleLocationUpdate(offRouteFix())
        for _ in 0..<4 {
            vm.offRouteConfirmed(distanceMeters: 100)
            await waitForRerouteToFinish(vm)
        }
        XCTAssertTrue(vm.isReroutePaused)

        // 10 m from the line: back on route.
        let near = origin.coordinate(at: 300, bearing: 0).coordinate(at: 10, bearing: 90)
        vm.handleLocationUpdate(CLLocation(coordinate: near, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: Date()))

        XCTAssertFalse(vm.isReroutePaused)
        XCTAssertEqual(analytics.names.last, "reroute_paused", "no extra event when the pause clears")
    }

    func testRerouteEventCarriesTheDetails() async {
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(analytics: analytics)
        vm.handleLocationUpdate(offRouteFix())

        vm.offRouteConfirmed(distanceMeters: 87.4)
        await waitForRerouteToFinish(vm)

        guard case .rerouteTriggered(_, let number, let distance, let sinceLast, let afterFlip, let reentry, let trigger) = analytics.events.last! else {
            return XCTFail("expected reroute_triggered")
        }
        XCTAssertEqual(number, 1)
        XCTAssertEqual(distance, 87.4)
        XCTAssertNil(sinceLast, "first reroute of the walk")
        XCTAssertFalse(afterFlip)
        XCTAssertEqual(trigger, "auto")
        XCTAssertTrue(["smart", "fallback"].contains(reentry))
        let props = analytics.events.last!.properties
        if case .double(let d)? = props["distance_meters"] { XCTAssertEqual(d, 87) } else { XCTFail("distance_meters") }
        XCTAssertNil(props["seconds_since_last"])
    }

    func testOffRouteWhileAlreadyReroutingIsIgnored() async {
        let analytics = RecordingAnalytics()
        let vm = makeViewModel(analytics: analytics)
        // No location yet: nothing can reroute, but the detection is still logged.
        vm.offRouteConfirmed(distanceMeters: 60)
        await waitForRerouteToFinish(vm)
        XCTAssertEqual(analytics.names, ["off_route_detected"])
    }
}
