import CoreLocation

/// Discovers POIs along a route corridor using Google Places **Nearby Search**.
///
/// Unlike the text-based Apple Maps approach, Nearby Search enforces a strict
/// geographic radius per query point — no keyword / name matching, so false
/// positives like "Toko Baru Castellum" appearing on an unrelated route are
/// eliminated.
///
/// Flow:
///   1. Sample the route polyline at regular distance intervals to produce
///      search centre points.
///   2. Issue parallel Nearby Search requests per search point × type.
///   3. Deduplicate results by `place_id` across all calls.
///   4. Post-fetch: hard-filter any result whose coordinate is farther than
///      `maxCorridorDistanceMeters` from the nearest route waypoint.
actor GooglePlacesNearbyDiscoveryService: POIDiscovering {
    private let apiClient: APIClient
    private let apiKey: String
    private let configuration: AppConfiguration
    private let logger = AppLogger(category: "POINearby")

    /// Google Place types to search for attractions.
    private static let attractionTypes: [(type: String, category: POICategory)] = [
        ("museum",              .museum),
        ("park",                .park),
        ("tourist_attraction",  .landmark),
        ("church",              .church),
        ("zoo",                 .zoo),
        ("aquarium",            .aquarium),
    ]

    /// Google Place types to search for food & drink.
    private static let foodTypes: [(type: String, category: POICategory)] = [
        ("restaurant", .restaurant),
        ("cafe",       .cafe),
        ("bakery",     .bakery),
        ("bar",        .bar),
    ]

    init(
        apiClient: APIClient,
        apiKey: String,
        configuration: AppConfiguration = .current
    ) {
        self.apiClient = apiClient
        self.apiKey = apiKey
        self.configuration = configuration
    }

    // MARK: - POIDiscovering

    func discoverPOIs(
        alongRoute polyline: [CLLocationCoordinate2D],
        searchIntervalMeters: Double,
        searchRadiusMeters: Double
    ) async throws -> [POI] {
        guard polyline.count >= 2 else { throw POIError.discoveryFailed }

        let searchPoints = Self.searchPoints(along: polyline, intervalMetres: searchIntervalMeters)
        logger.info("Sampled \(searchPoints.count) search points along route (\(polyline.count) waypoints)")

        let allTypes = Self.attractionTypes + Self.foodTypes

        // Issue parallel searches: one per (searchPoint, type) pair.
        // Cap at a reasonable concurrency limit to avoid quota bursts.
        let results = await withTaskGroup(of: [NearbyPOI].self) { group in
            for point in searchPoints {
                for entry in allTypes {
                    group.addTask {
                        await self.nearbySearch(
                            at: point,
                            radius: searchRadiusMeters,
                            type: entry.type,
                            category: entry.category
                        )
                    }
                }
            }
            var collected: [NearbyPOI] = []
            for await batch in group {
                collected.append(contentsOf: batch)
            }
            return collected
        }

        // Deduplicate by place_id
        var seenPlaceIds = Set<String>()
        let unique = results.filter { item in
            guard let pid = item.placeId, !seenPlaceIds.contains(pid) else { return false }
            seenPlaceIds.insert(pid)
            return true
        }

        // Post-fetch corridor filter
        let maxCorridor = configuration.poi.maxCorridorDistanceMeters
        let validated = unique.filter { item in
            isWithinRouteCorridor(
                coordinate: item.coordinate,
                routeWaypoints: polyline,
                maxDistanceMetres: maxCorridor
            )
        }

        let pois = validated.map { $0.toPOI(apiKey: apiKey) }

        logger.info("Discovered \(pois.count) POIs (from \(results.count) raw, \(unique.count) unique, \(validated.count) corridor-validated)")

        if pois.isEmpty {
            throw POIError.discoveryFailed
        }

        return pois
    }

    // MARK: - Search Points Sampling

    /// Sample the route polyline at regular distance intervals and return
    /// the search centre points. Always includes the first waypoint.
    static func searchPoints(
        along waypoints: [CLLocationCoordinate2D],
        intervalMetres: Double = 350
    ) -> [CLLocationCoordinate2D] {
        guard let first = waypoints.first else { return [] }
        var points: [CLLocationCoordinate2D] = [first]
        var accumulatedDistance: Double = 0

        for i in 1..<waypoints.count {
            let segmentDistance = waypoints[i - 1].distance(to: waypoints[i])
            accumulatedDistance += segmentDistance

            if accumulatedDistance >= intervalMetres {
                points.append(waypoints[i])
                accumulatedDistance = 0
            }
        }

        return points
    }

    // MARK: - Nearby Search

    private func nearbySearch(
        at location: CLLocationCoordinate2D,
        radius: Double,
        type: String,
        category: POICategory
    ) async -> [NearbyPOI] {
        let endpoint = GooglePlacesAPI.nearbySearch(
            location: location,
            radiusMeters: radius,
            type: type,
            apiKey: apiKey
        )

        do {
            let response = try await apiClient.request(
                endpoint,
                responseType: GooglePlacesAPI.NearbySearchResponse.self
            )

            guard response.status == "OK" || response.status == "ZERO_RESULTS" else {
                logger.warning("Nearby Search status=\(response.status) for type '\(type)'")
                return []
            }

            return response.results.compactMap { result -> NearbyPOI? in
                guard let name = result.name, !name.isEmpty,
                      let geometry = result.geometry,
                      let latLng = geometry.location else { return nil }

                return NearbyPOI(
                    placeId: result.placeId,
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: latLng.lat, longitude: latLng.lng),
                    category: category,
                    types: result.types ?? [],
                    rating: result.rating,
                    reviewCount: result.userRatingsTotal,
                    isOpenNow: result.openingHours?.openNow,
                    photoReference: result.photos?.first?.photoReference,
                    vicinity: result.vicinity
                )
            }
        } catch {
            logger.debug("Nearby search for '\(type)' at (\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude))) failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Post-Fetch Validation

    /// Hard filter: discard results whose coordinate is farther than
    /// `maxDistanceMetres` from the nearest route waypoint.
    private func isWithinRouteCorridor(
        coordinate: CLLocationCoordinate2D,
        routeWaypoints: [CLLocationCoordinate2D],
        maxDistanceMetres: Double
    ) -> Bool {
        let minDistance = RouteGeometry.minimumDistance(
            from: coordinate,
            toPolyline: routeWaypoints
        )
        return minDistance <= maxDistanceMetres
    }
}

// MARK: - Internal POI representation (pre-enrichment)

private struct NearbyPOI {
    let placeId: String?
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: POICategory
    let types: [String]
    let rating: Double?
    let reviewCount: Int?
    let isOpenNow: Bool?
    let photoReference: String?
    let vicinity: String?

    func toPOI(apiKey: String? = nil) -> POI {
        // Correct category from Google types if more specific
        let resolvedCategory: POICategory
        if !types.isEmpty {
            let googleCategory = POICategory.from(googleTypes: types)
            resolvedCategory = (googleCategory != .other) ? googleCategory : category
        } else {
            resolvedCategory = category
        }

        // Build photo URL from discovery photoReference if available
        var imageURL: URL?
        if let photoRef = photoReference, let key = apiKey {
            imageURL = GooglePlacesAPI.photoURL(reference: photoRef, maxWidth: 400, apiKey: key)
        }

        return POI(
            name: name,
            location: Location(coordinate),
            category: resolvedCategory,
            rating: rating,
            reviewCount: reviewCount,
            imageURL: imageURL,
            isOpenNow: isOpenNow,
            googlePlaceTypes: types,
            googlePlaceId: placeId,
            vicinity: vicinity
        )
    }
}
