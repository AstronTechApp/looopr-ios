import CoreLocation
import MapKit

actor AppleMapsPOIDiscoveryService: POIDiscovering {
    private let logger = AppLogger(category: "POIDiscovery")

    func discoverPOIs(
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) async throws -> [POI] {
        // Full implementation in Sprint 3
        logger.info("Discovering POIs at (\(center.latitude), \(center.longitude)), radius \(radiusMeters)m")
        return []
    }
}
