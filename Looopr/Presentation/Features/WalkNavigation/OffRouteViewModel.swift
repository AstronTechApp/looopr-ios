import CoreLocation

/// Pure detection state machine — does NOT perform rerouting.
/// Rerouting is orchestrated entirely by WalkNavigationViewModel.
@MainActor @Observable
final class OffRouteViewModel {
    private(set) var status: OffRouteDetector.OffRouteStatus = .onRoute

    var isOffRoute: Bool {
        if case .confirmed = status { return true }
        return false
    }

    var isDetecting: Bool {
        if case .detecting = status { return true }
        return false
    }

    var offRouteDistanceMeters: Double {
        switch status {
        case .onRoute:              return 0
        case .detecting(let d):    return d
        case .confirmed(let d):    return d
        }
    }

    private let offRouteDetector = OffRouteDetector()

    func check(
        userLocation: CLLocationCoordinate2D,
        horizontalAccuracy: Double,
        routePolyline: [CLLocationCoordinate2D]
    ) {
        status = offRouteDetector.check(
            userLocation: userLocation,
            horizontalAccuracy: horizontalAccuracy,
            polyline: routePolyline
        )
    }

    func reset() {
        offRouteDetector.reset()
        status = .onRoute
    }
}
