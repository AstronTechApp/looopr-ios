import CoreLocation

protocol RouteGenerating: Sendable {
    func generateLoopRoutes(
        start: CLLocationCoordinate2D,
        minutes: Int
    ) async throws -> [Route]

    func cancelInFlightRequests() async
}
