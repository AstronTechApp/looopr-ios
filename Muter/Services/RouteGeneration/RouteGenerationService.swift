import CoreLocation
import MapKit

actor LiveRouteGenerationService: RouteGenerating {
    private let configuration: AppConfiguration
    private let logger = AppLogger(category: "RouteGeneration")

    init(configuration: AppConfiguration = .current) {
        self.configuration = configuration
    }

    func generateLoopRoutes(
        start: CLLocationCoordinate2D,
        minutes: Int
    ) async throws -> [Route] {
        // Full implementation in Sprint 2
        logger.info("Generating routes for \(minutes) minutes")
        throw RouteError.noRoutesFound
    }

    func cancelInFlightRequests() async {
        // Will cancel in-flight MKDirections requests
    }
}
