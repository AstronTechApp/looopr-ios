import XCTest
import CoreLocation
@testable import Looopr

/// `distanceWalked` must count every metre of a walk at the ~1 Hz fix rate
/// used during navigation, ignore GPS jitter while standing still, and
/// skip glitches — regardless of how many reroutes happen in between.
@MainActor
final class WalkDistanceAccumulationTests: XCTestCase {

    private let origin = CLLocationCoordinate2D(latitude: 52.3677, longitude: 4.8845)

    private func makeViewModel() -> WalkNavigationViewModel {
        let route = Route(name: "Test Loop", durationMinutes: 30, distanceKilometers: 2.5,
                          coordinates: [Location(latitude: 52.3677, longitude: 4.8845),
                                        Location(latitude: 52.3690, longitude: 4.8845)],
                          startLocation: Location(latitude: 52.3677, longitude: 4.8845))
        return WalkNavigationViewModel(route: route)
    }

    func testOneHertzFixesAtWalkingPaceAreAllCounted() {
        let vm = makeViewModel()
        // 1.2 m per fix, straight north — every fix is below the old 2 m
        // fix-to-fix floor, which is exactly what lost 3 km on 17 Oct.
        for i in 0...500 {
            vm.accumulateDistance(to: origin.coordinate(at: Double(i) * 1.2, bearing: 0))
        }
        XCTAssertEqual(vm.distanceWalked, 600, accuracy: 6, "600 m walked must be ~600 m counted")
        XCTAssertEqual(vm.session.distanceWalkedMeters, vm.distanceWalked)
    }

    func testJitterWhileStandingStillDoesNotAccumulate() {
        let vm = makeViewModel()
        vm.accumulateDistance(to: origin)
        for i in 0..<300 {
            // Wander up to 4 m around the same spot.
            let wobble = origin.coordinate(at: Double(i % 5), bearing: Double((i * 73) % 360))
            vm.accumulateDistance(to: wobble)
        }
        XCTAssertEqual(vm.distanceWalked, 0, "sub-threshold wobble around one point is not walking")
    }

    func testGlitchJumpIsSkippedButReanchors() {
        let vm = makeViewModel()
        vm.accumulateDistance(to: origin)
        vm.accumulateDistance(to: origin.coordinate(at: 10, bearing: 0))
        let farAway = origin.coordinate(at: 400, bearing: 90)
        vm.accumulateDistance(to: farAway)
        XCTAssertEqual(vm.distanceWalked, 10, accuracy: 0.1, "a 400 m jump is not counted")
        vm.accumulateDistance(to: farAway.coordinate(at: 10, bearing: 90))
        XCTAssertEqual(vm.distanceWalked, 20, accuracy: 0.1, "but counting continues from the new position")
    }
}
