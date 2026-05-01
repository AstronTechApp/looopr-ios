import CoreLocation

protocol RouteGenerating: Sendable {
    func generateLoopRoutes(
        start: CLLocationCoordinate2D,
        minutes: Int,
        walkingSpeedKmH: Double
    ) async throws -> [Route]

    /// Streams routes as they are generated — each route is yielded immediately.
    /// Generation stops once `maxRoutes` routes have been yielded.
    func generateLoopRoutesStream(
        start: CLLocationCoordinate2D,
        minutes: Int,
        maxRoutes: Int,
        walkingSpeedKmH: Double
    ) -> AsyncThrowingStream<Route, Error>

    func cancelInFlightRequests() async
}
