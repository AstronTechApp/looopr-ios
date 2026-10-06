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

    func testAngleDelta() {
        XCTAssertEqual(SmoothedLocationTracker.angleDelta(350, 10), 20)
        XCTAssertEqual(SmoothedLocationTracker.angleDelta(10, 350), -20)
        XCTAssertEqual(SmoothedLocationTracker.angleDelta(0, 180), 180)
    }
}
