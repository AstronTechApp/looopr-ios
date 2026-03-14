import CoreLocation
import MapKit

actor LiveNavigationDirectionsService: NavigationDirecting {
    private let logger = AppLogger(category: "Navigation")

    func computeSteps(for route: Route) async throws -> [NavigationStep] {
        // Full implementation in Sprint 4
        if let steps = route.navigationSteps {
            return steps
        }
        throw NavigationError.stepsUnavailable
    }

    func computeDetour(
        from current: CLLocationCoordinate2D,
        to target: CLLocationCoordinate2D
    ) async throws -> DetourResult {
        // Full implementation in Sprint 4
        throw NavigationError.rerouteFailed
    }
}
