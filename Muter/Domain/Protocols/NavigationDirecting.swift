import CoreLocation

protocol NavigationDirecting: Sendable {
    func computeSteps(for route: Route) async throws -> [NavigationStep]
    func computeDetour(
        from current: CLLocationCoordinate2D,
        to target: CLLocationCoordinate2D
    ) async throws -> DetourResult
}

struct DetourResult: Sendable {
    let steps: [NavigationStep]
    let polylineCoordinates: [CLLocationCoordinate2D]
}
