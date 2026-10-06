import XCTest
import CoreLocation
@testable import Looopr

/// The tracker decides where the navigation puck is drawn. These tests pin
/// down the three behaviours it exists for: snapping to the route,
/// gliding between fixes instead of jumping, and turning smoothly.
@MainActor
final class SmoothedLocationTrackerTests: XCTestCase {

    // A straight 200 m street running due north through Amsterdam.
    private let origin = CLLocationCoordinate2D(latitude: 52.3700, longitude: 4.8900)
    private var street: [CLLocationCoordinate2D] {
        [origin, origin.coordinate(at: 100, bearing: 0), origin.coordinate(at: 200, bearing: 0)]
    }

    private func fix(_ coordinate: CLLocationCoordinate2D,
                     accuracy: Double = 5,
                     speed: Double = 1.4,
                     course: Double = 0,
                     at seconds: TimeInterval) -> CLLocation {
        CLLocation(coordinate: coordinate,
                   altitude: 0,
                   horizontalAccuracy: accuracy,
                   verticalAccuracy: 5,
                   course: course,
                   speed: speed,
                   timestamp: Date(timeIntervalSinceNow: seconds - 2))
    }

    private func makeTracker() -> SmoothedLocationTracker {
        let tracker = SmoothedLocationTracker()
        tracker.setRoute(street)
        tracker.start(initialCoordinate: nil, initialHeading: 0)
        tracker.stop() // no display link in tests; frames are driven by hand
        return tracker
    }

    /// Runs the display loop for `seconds` at 30 fps starting at `from`.
    private func run(_ tracker: SmoothedLocationTracker, from: TimeInterval, seconds: TimeInterval) -> TimeInterval {
        var now = from
        let dt = 1.0 / 30
        var elapsed = 0.0
        while elapsed < seconds {
            now += dt; elapsed += dt
            tracker.step(now: now, dt: dt)
        }
        return now
    }

    // MARK: - Projection

    func testProjectionLandsOnRouteWithCorrectBearing() {
        // 6 m east of the street, 50 m along it.
        let offStreet = origin.coordinate(at: 50, bearing: 0).coordinate(at: 6, bearing: 90)
        let projection = try! XCTUnwrap(SmoothedLocationTracker.project(offStreet, onto: street))
        XCTAssertEqual(projection.distanceMeters, 6, accuracy: 0.2)
        XCTAssertEqual(projection.coordinate.distance(to: origin.coordinate(at: 50, bearing: 0)), 0, accuracy: 0.3)
        XCTAssertEqual(projection.segmentBearing, 0, accuracy: 0.5)
    }

    func testProjectionClampsToSegmentEnds() {
        let beyondEnd = origin.coordinate(at: 230, bearing: 0)
        let projection = try! XCTUnwrap(SmoothedLocationTracker.project(beyondEnd, onto: street))
        XCTAssertEqual(projection.coordinate.distance(to: origin.coordinate(at: 200, bearing: 0)), 0, accuracy: 0.3)
        XCTAssertEqual(projection.distanceMeters, 30, accuracy: 0.5)
    }

    // MARK: - Snapping

    func testNearbyFixIsSnappedToRoute() {
        let tracker = makeTracker()
        let wobbly = origin.coordinate(at: 20, bearing: 0).coordinate(at: 7, bearing: 90)
        tracker.ingest(fix(wobbly, at: 0), now: 1_000)
        XCTAssertTrue(tracker.isSnappedToRoute)
        let shown = try! XCTUnwrap(tracker.displayCoordinate)
        XCTAssertEqual(shown.distance(to: origin.coordinate(at: 20, bearing: 0)), 0, accuracy: 0.3,
                       "Lateral GPS wobble must be removed by snapping")
    }

    func testFarFixIsShownRawSoDetoursStayVisible() {
        let tracker = makeTracker()
        let detour = origin.coordinate(at: 20, bearing: 0).coordinate(at: 40, bearing: 90)
        tracker.ingest(fix(detour, at: 0), now: 1_000)
        XCTAssertFalse(tracker.isSnappedToRoute)
        XCTAssertEqual(tracker.displayCoordinate!.distance(to: detour), 0, accuracy: 0.01)
    }

    func testInaccurateAndStaleFixesAreIgnoredForDisplay() {
        let tracker = makeTracker()
        tracker.ingest(fix(origin, accuracy: 80, at: 0), now: 1_000)
        XCTAssertNil(tracker.displayCoordinate, "80 m accuracy must not move the puck")
        let stale = CLLocation(coordinate: origin, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
                               course: 0, speed: 1, timestamp: Date(timeIntervalSinceNow: -60))
        tracker.ingest(stale, now: 1_000)
        XCTAssertNil(tracker.displayCoordinate, "a cached minute-old fix must not move the puck")
    }

    // MARK: - Interpolation

    func testPuckGlidesTowardNewFixInsteadOfJumping() {
        let tracker = makeTracker()
        tracker.ingest(fix(origin, speed: 0, at: 0), now: 1_000)
        // Standing still, then a fix 5 m further along arrives.
        tracker.ingest(fix(origin.coordinate(at: 5, bearing: 0), speed: 0, at: 1), now: 1_001)

        let shownImmediately = tracker.displayCoordinate!.distance(to: origin)
        XCTAssertEqual(shownImmediately, 0, accuracy: 0.05, "no teleport on arrival")

        _ = run(tracker, from: 1_001, seconds: 0.3)
        let partway = tracker.displayCoordinate!.distance(to: origin)
        XCTAssertGreaterThan(partway, 1)
        XCTAssertLessThan(partway, 4.5, "0.3 s in, the puck should still be on its way")

        _ = run(tracker, from: 1_001.3, seconds: 3)
        XCTAssertEqual(tracker.displayCoordinate!.distance(to: origin), 5, accuracy: 0.1,
                       "it settles exactly on the fix")
    }

    func testPuckKeepsWalkingBetweenFixesWhenMoving() {
        let tracker = makeTracker()
        tracker.ingest(fix(origin, speed: 1.4, at: 0), now: 1_000)
        tracker.ingest(fix(origin.coordinate(at: 1.4, bearing: 0), speed: 1.4, at: 1), now: 1_001)
        _ = run(tracker, from: 1_001, seconds: 1.5)
        let progressed = tracker.displayCoordinate!.distance(to: origin)
        XCTAssertGreaterThan(progressed, 1.4, "extrapolation carries the puck past the last fix")
        XCTAssertLessThan(progressed, 1.4 + 1.4 * 2 + 0.1, "but never further than the extrapolation cap")
        XCTAssertTrue(tracker.isSnappedToRoute)
        XCTAssertEqual(SmoothedLocationTracker.project(tracker.displayCoordinate!, onto: street)!.distanceMeters,
                       0, accuracy: 0.2, "extrapolated position stays on the route")
    }

    func testLargeJumpTeleports() {
        let tracker = makeTracker()
        tracker.ingest(fix(origin, speed: 0, at: 0), now: 1_000)
        let farAway = origin.coordinate(at: 150, bearing: 0)
        tracker.ingest(fix(farAway, speed: 0, at: 1), now: 1_001)
        _ = run(tracker, from: 1_001, seconds: 0.1)
        XCTAssertEqual(tracker.displayCoordinate!.distance(to: farAway), 0, accuracy: 0.1)
    }

    // MARK: - Heading

    func testHeadingEasesTowardCompassAcrossTheNorthWrap() {
        let tracker = makeTracker()
        tracker.ingest(fix(origin, speed: 0, at: 0), now: 1_000)
        tracker.ingestHeading(350) // start facing just west of north
        _ = run(tracker, from: 1_000, seconds: 3)
        XCTAssertEqual(tracker.displayHeading, 350, accuracy: 0.5)

        tracker.ingestHeading(10) // turn 20° clockwise through north
        _ = run(tracker, from: 1_003, seconds: 0.2)
        let midway = tracker.displayHeading
        XCTAssertTrue(midway > 350 || midway < 10, "must rotate the short way through 0°, got \(midway)")
        _ = run(tracker, from: 1_003.2, seconds: 3)
        XCTAssertEqual(tracker.displayHeading, 10, accuracy: 0.5)
    }

    func testRouteBearingWinsOverCompassWhileWalkingOnRoute() {
        let tracker = makeTracker()
        tracker.ingestHeading(90) // phone held sideways
        tracker.ingest(fix(origin, speed: 1.4, course: 0, at: 0), now: 1_000)
        tracker.ingest(fix(origin.coordinate(at: 1.4, bearing: 0), speed: 1.4, course: 0, at: 1), now: 1_001)
        _ = run(tracker, from: 1_001, seconds: 3)
        XCTAssertEqual(tracker.displayHeading, 0, accuracy: 1, "map faces along the street, not the phone")
    }

    // MARK: - Reverse-direction walking

    /// Feeds one fix per second walking from `start` along `bearing` with
    /// the GPS course set to that bearing. Returns the last fix time.
    @discardableResult
    private func walk(_ tracker: SmoothedLocationTracker, from start: CLLocationCoordinate2D,
                      bearing: Double, course: Double? = nil, seconds: Int,
                      startingAt t0: TimeInterval, speed: Double = 1.4) -> TimeInterval {
        var t = t0
        for i in 0...seconds {
            t = t0 + Double(i)
            let position = start.coordinate(at: speed * Double(i), bearing: bearing)
            tracker.ingest(fix(position, speed: speed, course: course ?? bearing, at: t), now: 1_000 + t)
        }
        return t
    }

    func testWalkingAgainstRouteSetsReversedOnlyAfterHoldTime() {
        let tracker = makeTracker()
        let top = origin.coordinate(at: 150, bearing: 0)
        // Heading south on a northbound street: 180° off.
        walk(tracker, from: top, bearing: 180, seconds: 2, startingAt: 0)
        XCTAssertFalse(tracker.isReversed, "2 s is not enough to count as a reversal")
        walk(tracker, from: top.coordinate(at: 1.4 * 3, bearing: 180), bearing: 180, seconds: 1, startingAt: 3)
        XCTAssertTrue(tracker.isReversed, "3 s of walking against the route flips the state")
    }

    func testReversalClearsOnlyAfterWalkingForwardForHoldTime() {
        let tracker = makeTracker()
        let top = origin.coordinate(at: 150, bearing: 0)
        walk(tracker, from: top, bearing: 180, seconds: 4, startingAt: 0)
        XCTAssertTrue(tracker.isReversed)

        // Turn around and walk north again.
        let turn = top.coordinate(at: 1.4 * 4, bearing: 180)
        walk(tracker, from: turn, bearing: 0, seconds: 2, startingAt: 5)
        XCTAssertTrue(tracker.isReversed, "still reversed after 2 s forward")
        walk(tracker, from: turn.coordinate(at: 1.4 * 3, bearing: 0), bearing: 0, seconds: 1, startingAt: 8)
        XCTAssertFalse(tracker.isReversed, "3 s forward clears the reversal")
    }

    func testReversalHysteresisDeadBandHoldsState() {
        let tracker = makeTracker()
        let top = origin.coordinate(at: 150, bearing: 0)
        // Course 90° off while the fixes stay on the street: not enough to
        // enter (>120°) and not enough to exit (<60°).
        walk(tracker, from: top, bearing: 180, course: 90, seconds: 6, startingAt: 0)
        XCTAssertFalse(tracker.isReversed, "a sideways course never enters the reversed state")

        walk(tracker, from: top, bearing: 180, seconds: 4, startingAt: 10)
        XCTAssertTrue(tracker.isReversed)
        // Sideways course for a long time: must not clear either.
        walk(tracker, from: top, bearing: 180, course: 90, seconds: 6, startingAt: 20)
        XCTAssertTrue(tracker.isReversed, "the dead band keeps the current state")
    }

    func testReversalRunIsBrokenByStandingStill() {
        let tracker = makeTracker()
        let top = origin.coordinate(at: 150, bearing: 0)
        walk(tracker, from: top, bearing: 180, seconds: 2, startingAt: 0)
        // Pause for a fix (no valid course, no speed), then 2 more seconds.
        tracker.ingest(fix(top.coordinate(at: 2.8, bearing: 180), speed: 0, course: -1, at: 3), now: 1_003)
        walk(tracker, from: top.coordinate(at: 2.8, bearing: 180), bearing: 180, seconds: 2, startingAt: 4)
        XCTAssertFalse(tracker.isReversed, "'continuously' means a pause restarts the 3 s clock")
    }

    func testReversalThresholdsAreTunable() {
        let tracker = makeTracker()
        tracker.reversalEnterSeconds = 1
        let top = origin.coordinate(at: 150, bearing: 0)
        walk(tracker, from: top, bearing: 180, seconds: 1, startingAt: 0)
        XCTAssertTrue(tracker.isReversed)
    }

    func testSetRouteResetsReversal() {
        let tracker = makeTracker()
        walk(tracker, from: origin.coordinate(at: 150, bearing: 0), bearing: 180, seconds: 4, startingAt: 0)
        XCTAssertTrue(tracker.isReversed)
        tracker.setRoute(street)
        XCTAssertFalse(tracker.isReversed)
    }

    func testHeadingFacesBackAlongRouteWhenReversed() {
        let tracker = makeTracker()
        tracker.ingestHeading(0)
        let top = origin.coordinate(at: 150, bearing: 0)
        let t = walk(tracker, from: top, bearing: 180, seconds: 4, startingAt: 0)
        XCTAssertTrue(tracker.isReversed)
        _ = run(tracker, from: 1_000 + t, seconds: 3)
        XCTAssertEqual(tracker.displayHeading, 180, accuracy: 1,
                       "puck arrow points down the street the way the user is actually walking")
    }

    func testExtrapolationRunsBackwardsWhenReversed() {
        let tracker = makeTracker()
        let top = origin.coordinate(at: 150, bearing: 0)
        let t = walk(tracker, from: top, bearing: 180, seconds: 4, startingAt: 0)
        let lastFix = top.coordinate(at: 1.4 * 4, bearing: 180)
        _ = run(tracker, from: 1_000 + t, seconds: 1.5)
        let shown = tracker.displayCoordinate!
        let alongFromOrigin = SmoothedLocationTracker.project(shown, onto: street)!.distanceAlongRouteMeters
        let lastFixAlong = SmoothedLocationTracker.project(lastFix, onto: street)!.distanceAlongRouteMeters
        XCTAssertLessThan(alongFromOrigin, lastFixAlong - 0.5,
                          "between fixes the puck keeps moving toward the route start, not its end")
        XCTAssertTrue(tracker.isSnappedToRoute)
    }

    func testProjectionReportsDistanceAlongRoute() {
        let point = origin.coordinate(at: 130, bearing: 0).coordinate(at: 4, bearing: 270)
        let projection = SmoothedLocationTracker.project(point, onto: street)!
        XCTAssertEqual(projection.distanceAlongRouteMeters, 130, accuracy: 0.3)
    }

    func testAngleDelta() {
        XCTAssertEqual(SmoothedLocationTracker.angleDelta(350, 10), 20)
        XCTAssertEqual(SmoothedLocationTracker.angleDelta(10, 350), -20)
        XCTAssertEqual(SmoothedLocationTracker.angleDelta(0, 180), 180)
    }
}
