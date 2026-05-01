import CoreLocation

protocol POIDiscovering: Sendable {
    /// Discover POIs along a route corridor using multiple search points
    /// sampled at regular intervals along the polyline.
    /// - Parameters:
    ///   - polyline: The route's ordered waypoints.
    ///   - searchIntervalMeters: Spacing between query points along the route.
    ///   - searchRadiusMeters: Radius per query point (strict geographic filter).
    func discoverPOIs(
        alongRoute polyline: [CLLocationCoordinate2D],
        searchIntervalMeters: Double,
        searchRadiusMeters: Double
    ) async throws -> [POI]
}
