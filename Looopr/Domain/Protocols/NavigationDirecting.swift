import CoreLocation

protocol NavigationDirecting: Sendable {
    func computeSteps(for route: Route) async throws -> [NavigationStep]
    func computeDetour(
        from current: CLLocationCoordinate2D,
        to target: CLLocationCoordinate2D
    ) async throws -> DetourResult

    /// Compute walking directions along an arbitrary sequence of coordinates.
    /// Returns turn-by-turn steps **and** the actual walkable polyline from MKDirections.
    func computeStepsAlongPath(
        _ coordinates: [CLLocationCoordinate2D]
    ) async throws -> RerouteResult
}

struct DetourResult: Sendable {
    let steps: [NavigationStep]
    let polylineCoordinates: [CLLocationCoordinate2D]
}

struct RerouteResult: Sendable {
    let steps: [NavigationStep]
    let polyline: [CLLocationCoordinate2D]
}
