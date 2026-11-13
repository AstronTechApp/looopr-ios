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

    /// Same as above, but may report what it has found so far through
    /// `onPartialResults` while slower searches are still being retried
    /// (for example after the search provider throttled some of them).
    /// The value returned at the end is always the complete set.
    ///
    /// Throws `POIError.searchUnavailable` when nothing was found because
    /// searches failed, so callers can tell that apart from "no sights here".
    func discoverPOIs(
        alongRoute polyline: [CLLocationCoordinate2D],
        searchIntervalMeters: Double,
        searchRadiusMeters: Double,
        onPartialResults: (@Sendable ([POI]) async -> Void)?
    ) async throws -> [POI]
}

extension POIDiscovering {
    /// Default for discoverers that have no retry pass: no partial results.
    func discoverPOIs(
        alongRoute polyline: [CLLocationCoordinate2D],
        searchIntervalMeters: Double,
        searchRadiusMeters: Double,
        onPartialResults: (@Sendable ([POI]) async -> Void)?
    ) async throws -> [POI] {
        try await discoverPOIs(
            alongRoute: polyline,
            searchIntervalMeters: searchIntervalMeters,
            searchRadiusMeters: searchRadiusMeters
        )
    }
}
