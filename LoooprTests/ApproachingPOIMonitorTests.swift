import XCTest
import CoreLocation
@testable import Looopr

/// The monitor decides when the "Approaching" banner appears and goes
/// away. Distances are along the route, never as the crow flies.
@MainActor
final class ApproachingPOIMonitorTests: XCTestCase {

    // A 1 km street due north, one vertex every 100 m.
    private let origin = CLLocationCoordinate2D(latitude: 52.3700, longitude: 4.8900)
    private var street: [CLLocationCoordinate2D] {
        (0...10).map { origin.coordinate(at: Double($0) * 100, bearing: 0) }
    }

    /// An attraction `along` metres up the street, `aside` metres to the east.
    private func poi(_ name: String, along: Double, aside: Double = 5) -> POI {
        let c = origin.coordinate(at: along, bearing: 0).coordinate(at: aside, bearing: 90)
        return POI(name: name,
                   location: Location(latitude: c.latitude, longitude: c.longitude),
                   category: .museum)
    }

    private func makeMonitor(pois: [POI]) -> ApproachingPOIMonitor {
        let monitor = ApproachingPOIMonitor()
        monitor.setRoute(street, pois: pois)
        return monitor
    }

    // MARK: - Showing

    func testBannerAppearsAtAlongRouteThresholdAndNotBefore() {
        let monitor = makeMonitor(pois: [poi("Museum", along: 500)])
        XCTAssertNil(monitor.update(userAlongRouteMeters: 390, isReversed: false, now: 0))
        let shown = monitor.update(userAlongRouteMeters: 401, isReversed: false, now: 1)
        XCTAssertEqual(shown?.poi.name, "Museum")
        XCTAssertEqual(shown?.distanceMeters ?? -1, 99, accuracy: 1)
    }

    func testPOIBehindUserIsNotShown() {
        let monitor = makeMonitor(pois: [poi("Museum", along: 500)])
        XCTAssertNil(monitor.update(userAlongRouteMeters: 530, isReversed: false, now: 0),
                     "30 m past the museum, walking away from it")
    }

    func testDirectionOfTravelDecidesWhatIsAhead() {
        let monitor = makeMonitor(pois: [poi("Museum", along: 500)])
        // Walking the street backwards: the museum at 500 is ahead when the
        // user is at 530, and behind when at 470.
        XCTAssertEqual(monitor.update(userAlongRouteMeters: 530, isReversed: true, now: 0)?.poi.name, "Museum")
        XCTAssertEqual(monitor.update(userAlongRouteMeters: 530, isReversed: true, now: 0)?.distanceMeters ?? -1,
                       30, accuracy: 1)

        let other = makeMonitor(pois: [poi("Museum", along: 500)])
        XCTAssertNil(other.update(userAlongRouteMeters: 470, isReversed: true, now: 0))
    }

    func testAlongRouteDistanceNotStraightLine() {
        // A hairpin: north 300 m, then back south 300 m on a parallel
        // street 20 m to the east. A POI on the return leg is 20 m away as
        // the crow flies from the outbound leg but ~580 m away on foot.
        let up = (0...3).map { origin.coordinate(at: Double($0) * 100, bearing: 0) }
        let down = (0...3).map { origin.coordinate(at: 300 - Double($0) * 100, bearing: 0).coordinate(at: 20, bearing: 90) }
        let hairpin = up + down
        let onReturnLeg = POI(name: "Café",
                              location: Location(latitude: down[3].latitude, longitude: down[3].longitude),
                              category: .museum)
        let monitor = ApproachingPOIMonitor()
        monitor.setRoute(hairpin, pois: [onReturnLeg])
        // User 10 m up the outbound leg: straight-line distance ≈ 22 m.
        XCTAssertNil(monitor.update(userAlongRouteMeters: 10, isReversed: false, now: 0),
                     "no banner: the café is 590 m away along the route")
        XCTAssertNotNil(monitor.update(userAlongRouteMeters: 530, isReversed: false, now: 1))
    }

    func testNearestPOIAheadWinsAndOnlyOneShows() {
        let monitor = makeMonitor(pois: [poi("Far", along: 580), poi("Near", along: 550)])
        let shown = monitor.update(userAlongRouteMeters: 500, isReversed: false, now: 0)
        XCTAssertEqual(shown?.poi.name, "Near")
    }

    func testDistanceCountsDownAsUserApproaches() {
        let monitor = makeMonitor(pois: [poi("Museum", along: 500)])
        _ = monitor.update(userAlongRouteMeters: 420, isReversed: false, now: 0)
        let later = monitor.update(userAlongRouteMeters: 460, isReversed: false, now: 30)
        XCTAssertEqual(later?.distanceMeters ?? -1, 40, accuracy: 1)
    }

    // MARK: - Hiding

    func testBannerHidesTwentyMetresPastThePOI() {
        let monitor = makeMonitor(pois: [poi("Museum", along: 500)])
        _ = monitor.update(userAlongRouteMeters: 450, isReversed: false, now: 0)
        XCTAssertNotNil(monitor.update(userAlongRouteMeters: 500, isReversed: false, now: 1))
        XCTAssertNotNil(monitor.update(userAlongRouteMeters: 518, isReversed: false, now: 2),
                        "still shown just past the POI")
        XCTAssertNil(monitor.update(userAlongRouteMeters: 521, isReversed: false, now: 3),
                     "hidden 20 m past")
    }

    func testBannerHidesAfterTenSecondsLingeringNearThePOI() {
        let monitor = makeMonitor(pois: [poi("Museum", along: 500)])
        _ = monitor.update(userAlongRouteMeters: 450, isReversed: false, now: 0)
        XCTAssertNotNil(monitor.update(userAlongRouteMeters: 490, isReversed: false, now: 10), "within 15 m")
        XCTAssertNotNil(monitor.update(userAlongRouteMeters: 492, isReversed: false, now: 19), "9 s in")
        XCTAssertNil(monitor.update(userAlongRouteMeters: 492, isReversed: false, now: 20), "10 s in")
    }

    func testLingerTimerResetsWhenUserLeavesTheRadius() {
        let monitor = makeMonitor(pois: [poi("Museum", along: 500)])
        _ = monitor.update(userAlongRouteMeters: 450, isReversed: false, now: 0)
        _ = monitor.update(userAlongRouteMeters: 490, isReversed: false, now: 10)
        _ = monitor.update(userAlongRouteMeters: 480, isReversed: false, now: 16) // stepped back out
        XCTAssertNotNil(monitor.update(userAlongRouteMeters: 490, isReversed: false, now: 25),
                        "only 5 s of the new stay within the radius have passed")
    }

    func testPassedPOIIsNotShownAgainWhenUserTurnsAround() {
        let monitor = makeMonitor(pois: [poi("Museum", along: 500)])
        _ = monitor.update(userAlongRouteMeters: 450, isReversed: false, now: 0)
        XCTAssertNil(monitor.update(userAlongRouteMeters: 525, isReversed: false, now: 1))
        XCTAssertNil(monitor.update(userAlongRouteMeters: 525, isReversed: true, now: 2),
                     "walking back toward it does not resurrect the banner")
    }

    func testDismissedPOIStaysHiddenAcrossReroutes() {
        let museum = poi("Museum", along: 500)
        let monitor = makeMonitor(pois: [museum])
        XCTAssertNotNil(monitor.update(userAlongRouteMeters: 450, isReversed: false, now: 0))
        monitor.dismiss()
        XCTAssertNil(monitor.current)
        XCTAssertNil(monitor.update(userAlongRouteMeters: 460, isReversed: false, now: 1))
        monitor.setRoute(street, pois: [museum]) // reroute
        XCTAssertNil(monitor.update(userAlongRouteMeters: 470, isReversed: false, now: 2))
    }

    func testNextPOIShowsAfterPreviousIsPassed() {
        let monitor = makeMonitor(pois: [poi("First", along: 500), poi("Second", along: 560)])
        XCTAssertEqual(monitor.update(userAlongRouteMeters: 480, isReversed: false, now: 0)?.poi.name, "First")
        XCTAssertEqual(monitor.update(userAlongRouteMeters: 525, isReversed: false, now: 1)?.poi.name, "Second")
    }

    func testOffRouteHidesWithoutRetiring() {
        let monitor = makeMonitor(pois: [poi("Museum", along: 500)])
        XCTAssertNotNil(monitor.update(userAlongRouteMeters: 450, isReversed: false, now: 0))
        XCTAssertNil(monitor.update(userAlongRouteMeters: nil, isReversed: false, now: 1))
        XCTAssertNotNil(monitor.update(userAlongRouteMeters: 455, isReversed: false, now: 2))
    }
}
