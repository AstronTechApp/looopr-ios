import CoreLocation

protocol POIDiscovering: Sendable {
    func discoverPOIs(
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) async throws -> [POI]
}
