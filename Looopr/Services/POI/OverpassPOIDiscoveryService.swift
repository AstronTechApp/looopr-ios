import CoreLocation
import Foundation

/// Discovers POIs along a route corridor using the **OpenStreetMap Overpass API**.
///
/// Drop-in replacement for `GooglePlacesNearbyDiscoveryService` — conforms
/// to the same `POIDiscovering` protocol and produces the same `POI` model.
///
/// **Key cost difference:**
///   - Google Places: ~112 API calls per route × $32/1k = ~$3.58 per route.
///   - Overpass:      **1 API call per route × $0** = free.
///
/// Trade-offs vs Google Places:
///   - No ratings, review counts, or photos from Overpass (OSM doesn't have them).
///   - Opening hours are available but in OSM's own format.
///   - Name coverage is excellent in Europe; patchier in some other regions.
///
/// The service can be combined with on-demand Google Place Details enrichment:
/// keep `GooglePlacesEnrichmentService` for the ~5–10 POIs a user actually
/// taps, instead of enriching 20 eagerly upfront.
actor OverpassPOIDiscoveryService: POIDiscovering {
    private let apiClient: APIClient
    private let configuration: AppConfiguration
    private let overpassBaseURL: String
    private let logger = AppLogger(category: "POIOverpass")

    /// Dedicated decoder for Overpass responses. The shared `URLSessionAPIClient`
    /// uses `keyDecodingStrategy = .convertFromSnakeCase` which conflicts with
    /// the Overpass `Tags` CodingKeys (e.g. `opening_hours` gets pre-converted
    /// to `openingHours`, then the explicit CodingKey mapping to `"opening_hours"`
    /// no longer matches). Using our own decoder avoids this entirely.
    private let decoder = JSONDecoder()

    init(
        apiClient: APIClient,
        configuration: AppConfiguration = .current,
        overpassBaseURL: String = OverpassAPI.defaultBaseURL
    ) {
        self.apiClient = apiClient
        self.configuration = configuration
        self.overpassBaseURL = overpassBaseURL
    }

    // MARK: - POIDiscovering

    func discoverPOIs(
        alongRoute polyline: [CLLocationCoordinate2D],
        searchIntervalMeters: Double,
        searchRadiusMeters: Double
    ) async throws -> [POI] {
        guard polyline.count >= 2 else { throw POIError.discoveryFailed }

        // 1. Sample the route polyline at regular intervals (reuses the same
        //    helper as the Google implementation).
        let points = Self.searchPoints(along: polyline, intervalMetres: searchIntervalMeters)
        logger.info("Sampled \(points.count) search points along route (\(polyline.count) waypoints)")

        // 2. Build a single Overpass query covering all search points + types.
        let searchCoords = points.map { (lat: $0.latitude, lon: $0.longitude) }
        let query = OverpassAPI.poiQuery(
            searchPoints: searchCoords,
            radiusMeters: searchRadiusMeters
        )

        // 3. Execute the query with retry — the public Overpass endpoint can
        //    throttle or timeout, especially after repeated requests. One retry
        //    with a short delay handles most transient failures.
        logger.info("Executing Overpass query with \(searchCoords.count) search coords, radius \(Int(searchRadiusMeters))m")
        let response = try await executeWithRetry(query: query)

        logger.info("Overpass returned \(response.elements.count) raw elements")
        if response.elements.isEmpty {
            logger.warning("⚠️ Overpass returned 0 elements — possible timeout or empty area. Query had \(searchCoords.count) search points at radius \(Int(searchRadiusMeters))m")
        }

        // 4. Convert OSM elements to POI objects.
        var seenIds = Set<Int>()
        let candidates: [POI] = response.elements.compactMap { element in
            // Require a name and coordinates (nodes have lat/lon directly;
            // ways and relations get a centroid via "out center")
            guard let tags = element.tags,
                  let name = tags.name, !name.isEmpty,
                  let lat = element.resolvedLat,
                  let lon = element.resolvedLon else {
                return nil
            }

            // Deduplicate by OSM node ID
            guard !seenIds.contains(element.id) else { return nil }
            seenIds.insert(element.id)

            let category = OverpassAPI.category(for: tags)
            let googleTypes = OverpassAPI.googleTypeEquivalents(for: tags)

            // Parse OSM opening_hours into a human-readable string
            let openingHours = tags.openingHours

            // Build website URL if available
            var websiteURL: URL?
            if let urlString = tags.website {
                websiteURL = URL(string: urlString)
            }

            // Wikidata presence = notability signal. Major landmarks, museums,
            // and galleries have Wikidata entries; small independent ones don't.
            let hasWikidata = tags.wikidata != nil && !tags.wikidata!.isEmpty

            return POI(
                name: name,
                location: Location(CLLocationCoordinate2D(latitude: lat, longitude: lon)),
                category: category,
                websiteURL: websiteURL,
                openingHours: openingHours,
                phoneNumber: tags.phone,
                detailedDescription: tags.description,
                googlePlaceTypes: googleTypes,
                // Use "osm:<id>" as a stable identifier for deduplication
                googlePlaceId: "osm:\(element.id)",
                isEnriched: false,
                hasWikidata: hasWikidata
            )
        }

        logger.info("Parsed \(candidates.count) named POIs from \(response.elements.count) raw elements")

        // 5. Post-fetch corridor filter — same logic as Google implementation.
        let maxCorridor = configuration.poi.maxCorridorDistanceMeters
        let validated = candidates.filter { poi in
            isWithinRouteCorridor(
                coordinate: poi.location.clCoordinate,
                routeWaypoints: polyline,
                maxDistanceMetres: maxCorridor
            )
        }

        logger.info("Discovered \(validated.count) POIs (from \(response.elements.count) raw, \(candidates.count) named, \(validated.count) corridor-validated)")

        // Return whatever we have — even an empty array. The aggregator
        // handles empty gracefully. Previously this threw discoveryFailed on
        // empty, which silently swallowed the diagnostic logs upstream.
        return validated
    }

    // MARK: - HTTP Execution with Retry

    /// Execute the Overpass query, decoding with our own JSONDecoder (no
    /// `convertFromSnakeCase`). Retries twice on transient failures (network
    /// errors, server 429/5xx, decode errors from HTML error pages).
    /// Bumped from 2 to 3 attempts — dense cities like London can hit
    /// transient Overpass timeouts that succeed on the second or third try.
    private func executeWithRetry(
        query: String,
        maxAttempts: Int = 3
    ) async throws -> OverpassAPI.OverpassResponse {
        var lastError: Error = POIError.discoveryFailed

        for attempt in 1...maxAttempts {
            do {
                let endpoint = OverpassAPI.interpreter(query: query, baseURL: overpassBaseURL)
                let (data, httpResponse) = try await apiClient.requestRaw(endpoint)

                // Check status code ourselves (bypassing the shared client's
                // decoder which uses convertFromSnakeCase).
                guard (200...299).contains(httpResponse.statusCode) else {
                    let bodyPreview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
                    logger.warning("Overpass HTTP \(httpResponse.statusCode) (attempt \(attempt)): \(bodyPreview)")

                    // Retry on 429 (rate limit) or 5xx (server error)
                    if httpResponse.statusCode == 429 || httpResponse.statusCode >= 500 {
                        lastError = NetworkError.invalidResponse(statusCode: httpResponse.statusCode)
                        if attempt < maxAttempts {
                            try await Task.sleep(nanoseconds: UInt64(2_000_000_000 * attempt))
                            continue
                        }
                    }
                    throw NetworkError.invalidResponse(statusCode: httpResponse.statusCode)
                }

                // Decode with our own decoder — no convertFromSnakeCase interference.
                do {
                    return try decoder.decode(OverpassAPI.OverpassResponse.self, from: data)
                } catch {
                    let bodyPreview = String(data: data.prefix(300), encoding: .utf8) ?? "<binary>"
                    logger.error("Overpass decode failed (attempt \(attempt)): \(error.localizedDescription). Body: \(bodyPreview)")
                    lastError = error
                    if attempt < maxAttempts {
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        continue
                    }
                }
            } catch let error as POIError {
                throw error
            } catch let error as NetworkError {
                throw error
            } catch {
                logger.warning("Overpass request failed (attempt \(attempt)): \(error.localizedDescription)")
                lastError = error
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(2_000_000_000 * attempt))
                    continue
                }
            }
        }

        throw lastError
    }

    // MARK: - Search Points Sampling

    /// Sample the route polyline at regular distance intervals and return
    /// the search centre points. Always includes the first waypoint.
    /// (Same algorithm as `GooglePlacesNearbyDiscoveryService.searchPoints`)
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

    // MARK: - Post-Fetch Validation

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
