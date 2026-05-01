import CoreLocation
import MapKit

/// Primary POI discovery service using Apple MapKit's `MKLocalSearch` with
/// natural-language queries. Replaces the Overpass-based discovery for tourist
/// attractions with faster, higher-quality results from Apple's POI database.
///
/// **Design decisions:**
///   - Uses `MKLocalSearch.Request` with `naturalLanguageQuery` and
///     `resultTypes = .pointOfInterest`. Does **NOT** set
///     `pointOfInterestFilter` — category filters combined with NL queries
///     are too restrictive in many regions (Amsterdam, NYC, etc.) where
///     Apple's POI categorisation is inconsistent, causing zero results.
///     Instead, non-attraction categories are rejected in post-processing.
///   - Searches at multiple points sampled along the route polyline (~500 m
///     intervals) to ensure full coverage — avoids the Overpass bug where POIs
///     only appeared near the start.
///   - Searches run in batches of `searchBatchSize` to avoid overwhelming
///     MKLocalSearch rate limits (which are undocumented but real).
///   - Deduplicates results across overlapping search regions by map-item name
///     + coordinate proximity.
///   - Produces the same `[POI]` output as `OverpassPOIDiscoveryService`,
///     conforming to `POIDiscovering` for drop-in replacement.
///
/// **What MapKit gives us that Overpass didn't:**
///   - Sub-second response times (local index, no HTTP round-trip to overpass-api.de).
///   - Apple-curated names and categories (fewer false positives).
///   - Placemark metadata: locality, URL, phone number.
///
/// **What it doesn't cover:**
///   - Very minor heritage sites and monuments — those may not appear in
///     Apple's POI index. The caller can supplement with Overpass if needed.
actor AppleMapKitDiscoveryService: POIDiscovering {

    private let configuration: AppConfiguration
    private let logger = AppLogger(category: "POIMapKit")

    // MARK: - Search Queries

    /// Natural-language queries for discovering tourist attractions.
    ///
    /// **Critical design decision:** These searches do NOT use
    /// `MKPointOfInterestFilter`. Category filters combined with NL queries
    /// are too restrictive in many regions — Apple's POI categorisation is
    /// inconsistent outside the US, causing museums tagged as `.landmark`
    /// (or untagged entirely) to be silently excluded. By omitting the filter
    /// we let MapKit's text-matching index do the heavy lifting, then
    /// categorise results ourselves using the returned
    /// `pointOfInterestCategory` plus a fallback inferred from the query.
    ///
    /// Each query has a `fallbackCategory` used when the returned MKMapItem
    /// has no `pointOfInterestCategory` or when its category doesn't map to
    /// a known attraction type.
    private struct AttractionQuery {
        let query: String
        let fallbackCategory: POICategory
    }

    private static let attractionQueries: [AttractionQuery] = [
        // Specific attraction types — targeted enough to produce relevant results
        AttractionQuery(query: "museum",                              fallbackCategory: .museum),
        AttractionQuery(query: "park garden",                         fallbackCategory: .park),
        AttractionQuery(query: "art gallery",                         fallbackCategory: .gallery),
        AttractionQuery(query: "castle palace",                       fallbackCategory: .castle),
        AttractionQuery(query: "monument memorial statue",            fallbackCategory: .monument),
        AttractionQuery(query: "church cathedral synagogue mosque",   fallbackCategory: .church),
        AttractionQuery(query: "historic site heritage",              fallbackCategory: .historicSite),
        // Broad catch-all — picks up attractions not covered by specific queries
        AttractionQuery(query: "tourist attraction landmark sightseeing", fallbackCategory: .landmark),
    ]

    /// MKPointOfInterestCategory values that are rejected even when returned
    /// by a tourist-attraction NL query. Without a `pointOfInterestFilter`
    /// on the request, MapKit may return nearby cafes, shops, or hotels
    /// whose name partially matches the query (e.g. "Museum Café").
    private static var rejectedMapKitCategories: Set<MKPointOfInterestCategory> {
        var rejected: Set<MKPointOfInterestCategory> = [
            .restaurant, .cafe, .bakery, .foodMarket,
            .store, .gasStation, .hotel,
            .pharmacy, .hospital, .bank, .atm,
            .postOffice, .school, .university,
            .airport, .parking, .carRental, .publicTransport,
            .evCharger, .fireStation, .police,
            .laundry, .fitnessCenter, .nightlife,
            .restroom, .marina,
        ]
        if #available(iOS 18.0, *) {
            rejected.insert(.automotiveRepair)
            rejected.insert(.spa)
            rejected.insert(.mailbox)
            rejected.insert(.animalService)
        }
        return rejected
    }

    /// Distance in metres between search sample points along the route.
    /// 500 m gives good overlap with a 600 m search region span (300 m radius).
    private static let sampleIntervalMeters: Double = 500

    /// Maximum distance (metres) a result may be from its search-circle centre
    /// to be kept. MKLocalSearch treats the region as a *hint* and routinely
    /// returns popular POIs far outside it (e.g. searching in north Amsterdam
    /// returns the Anne Frank House in the city centre). Without a hard cap the
    /// same famous POIs appear from every search point, causing clustering.
    /// Set to 1.5× the region radius so slight MapKit coordinate jitter is
    /// tolerated while genuinely distant results are discarded.
    private static let maxResultDistanceFromSearchCenter: Double = 450  // 1.5 × 300 m radius

    /// Coordinate proximity threshold for deduplication (metres).
    /// Two results with the same normalised name within this distance are
    /// considered the same place found from overlapping search circles.
    private static let deduplicationDistanceMeters: Double = 50

    /// Maximum number of concurrent MKLocalSearch requests per batch.
    /// Apple's rate limits are undocumented; batching prevents throttling
    /// that causes silent zero-result responses across all searches.
    private static let searchBatchSize = 15

    init(configuration: AppConfiguration = .current) {
        self.configuration = configuration
    }

    // MARK: - POIDiscovering

    func discoverPOIs(
        alongRoute polyline: [CLLocationCoordinate2D],
        searchIntervalMeters: Double,
        searchRadiusMeters: Double
    ) async throws -> [POI] {
        guard polyline.count >= 2 else { throw POIError.discoveryFailed }

        // 1. Sample search points along the route.
        let points = Self.searchPoints(
            along: polyline,
            intervalMetres: Self.sampleIntervalMeters
        )
        let queryCount = Self.attractionQueries.count
        let totalSearches = points.count * queryCount
        logger.info("Sampled \(points.count) search points along route (\(polyline.count) waypoints), \(queryCount) queries → \(totalSearches) total searches")

        // 2. Run searches for every (point × query) pair in batches.
        let allResults = await searchAllQueries(
            at: points,
            radiusMeters: searchRadiusMeters
        )
        logger.info("MapKit returned \(allResults.count) raw results across \(queryCount) queries and \(points.count) points")
        if allResults.isEmpty {
            logger.warning("⚠️ MapKit returned ZERO results for ALL \(totalSearches) searches — this likely indicates MKLocalSearch is failing silently (check network, entitlements, or simulator limitations)")
        }

        // 3. Deduplicate — the same landmark will appear from multiple
        //    overlapping search circles and from different queries.
        let unique = deduplicate(allResults)
        logger.info("After deduplication: \(unique.count) unique POIs")

        // 4. Corridor filter — discard anything too far from the route.
        let maxCorridor = configuration.poi.maxCorridorDistanceMeters
        let validated = unique.filter { poi in
            RouteGeometry.minimumDistance(
                from: poi.location.clCoordinate,
                toPolyline: polyline
            ) <= maxCorridor
        }

        logger.info("Discovered \(validated.count) POIs (from \(allResults.count) raw, \(unique.count) unique, \(validated.count) corridor-validated)")
        return validated
    }

    // MARK: - Batched Query Search

    /// Search every query at every sample point using structured concurrency,
    /// batched to avoid MKLocalSearch rate limits.
    ///
    /// Each batch of `searchBatchSize` searches runs concurrently; batches
    /// are sequential. Individual failures are swallowed (logged) so one bad
    /// search doesn't kill the whole discovery pass.
    private func searchAllQueries(
        at points: [CLLocationCoordinate2D],
        radiusMeters: Double
    ) async -> [POI] {
        struct SearchTask {
            let point: CLLocationCoordinate2D
            let query: AttractionQuery
        }

        let allTasks = points.flatMap { point in
            Self.attractionQueries.map { SearchTask(point: point, query: $0) }
        }

        var allResults: [POI] = []

        for batchStart in stride(from: 0, to: allTasks.count, by: Self.searchBatchSize) {
            let batchEnd = min(batchStart + Self.searchBatchSize, allTasks.count)
            let batch = allTasks[batchStart..<batchEnd]

            let batchResults = await withTaskGroup(of: [POI].self) { group in
                for task in batch {
                    group.addTask {
                        await self.search(
                            query: task.query.query,
                            fallbackCategory: task.query.fallbackCategory,
                            center: task.point,
                            radiusMeters: radiusMeters
                        )
                    }
                }

                var results: [POI] = []
                for await pois in group {
                    results.append(contentsOf: pois)
                }
                return results
            }

            allResults.append(contentsOf: batchResults)
        }

        return allResults
    }

    /// Single MKLocalSearch for one query at one point.
    ///
    /// **Critical:** Does NOT set `pointOfInterestFilter`. The previous
    /// implementation used both `naturalLanguageQuery` AND a category filter,
    /// which caused zero results in many cities (Amsterdam, NYC) because
    /// Apple's category tagging is inconsistent across regions. A museum
    /// tagged as `.landmark` (or untagged) would be excluded by a `.museum`
    /// filter even though the NL query matched correctly.
    ///
    /// Instead, we rely on `naturalLanguageQuery` + `resultTypes = .pointOfInterest`
    /// for discovery, and reject non-attraction categories in post-processing.
    private func search(
        query: String,
        fallbackCategory: POICategory,
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) async -> [POI] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        // NO pointOfInterestFilter — see class-level doc comment for rationale.
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let pois = response.mapItems.compactMap { item -> POI? in
                // Reject clearly non-attraction categories (cafes, stores, etc.)
                // that MapKit returned because their name partially matched the query.
                if let mkCat = item.pointOfInterestCategory,
                   Self.rejectedMapKitCategories.contains(mkCat) {
                    return nil
                }

                guard let poi = mapItemToPOI(item, fallbackCategory: fallbackCategory) else { return nil }

                // Hard proximity filter: MKLocalSearch treats the region as a
                // relevance hint and routinely returns famous POIs far outside
                // the search circle. Discard any result whose coordinate is
                // farther than maxResultDistanceFromSearchCenter from the
                // circle's centre so each search point only contributes truly
                // local results.
                let resultLocation = CLLocation(latitude: poi.location.latitude, longitude: poi.location.longitude)
                let distanceFromCenter = resultLocation.distance(from: centerLocation)
                guard distanceFromCenter <= Self.maxResultDistanceFromSearchCenter else {
                    return nil
                }

                return poi
            }
            if pois.isEmpty {
                logger.debug("MapKit returned 0 items for '\(query)' at (\(String(format: "%.4f", center.latitude)), \(String(format: "%.4f", center.longitude)))")
            }
            return pois
        } catch let error as MKError {
            // Separate MKError handling for better diagnostics:
            // .placemarkNotFound (code 4), .serverFailure (code 2), .loadingThrottled (code 3)
            logger.warning("MapKit search failed for '\(query)' at (\(String(format: "%.4f", center.latitude)), \(String(format: "%.4f", center.longitude))): MKError code=\(error.errorCode) \(error.localizedDescription)")
            return []
        } catch {
            logger.warning("MapKit search failed for '\(query)' at (\(String(format: "%.4f", center.latitude)), \(String(format: "%.4f", center.longitude))): \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - MKMapItem → POI Conversion

    private func mapItemToPOI(
        _ item: MKMapItem,
        fallbackCategory: POICategory
    ) -> POI? {
        guard let name = item.name, !name.isEmpty else { return nil }

        let coordinate = item.placemark.coordinate

        // Use MapKit's own category when it maps to a known attraction type.
        // If the category is nil (untagged) or maps to a non-attraction type,
        // fall back to the category implied by the search query that found it.
        // This handles regions where MapKit's category tagging is sparse —
        // e.g. a museum in Amsterdam with no pointOfInterestCategory still
        // gets classified as .museum because it was found by the "museum" query.
        let poiCategory: POICategory
        if let mkCat = item.pointOfInterestCategory {
            let mapped = POICategory.from(mapKitCategory: mkCat)
            poiCategory = mapped.isTouristAttraction ? mapped : fallbackCategory
        } else {
            poiCategory = fallbackCategory
        }

        // Build Apple Maps URL: maps.apple.com deep link with the place name + coordinates.
        let appleMapsURL = Self.appleMapsURL(name: name, coordinate: coordinate)

        // Matchable name for future GYG / Viator deep-link matching.
        let matchable = Self.matchableName(from: name)

        return POI(
            name: name,
            summary: item.placemark.title ?? "",
            location: Location(coordinate),
            category: poiCategory,
            websiteURL: item.url,
            phoneNumber: item.phoneNumber,
            // Use "mapkit:<name-hash>" as a stable-ish identifier for dedup
            googlePlaceId: "mapkit:\(Self.stableId(name: name, coordinate: coordinate))",
            locality: item.placemark.locality,
            isEnriched: false,
            appleMapsURL: appleMapsURL,
            matchableName: matchable,
            hasWikidata: false
        )
    }

    // MARK: - Apple Maps URL

    /// Construct an `maps.apple.com` URL that opens the place in Apple Maps.
    /// Uses `q=` (search query) + `ll=` (lat,lon) so the correct pin is shown
    /// even when the name is ambiguous.
    private static func appleMapsURL(
        name: String,
        coordinate: CLLocationCoordinate2D
    ) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: name),
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "z", value: "17"),
        ]
        return components?.url
    }

    // MARK: - Matchable Name (for GYG / Viator linking)

    /// Normalise a place name for fuzzy matching against activity provider catalogs.
    /// "The British Museum" → "british museum"
    /// "Buckingham Palace (State Rooms)" → "buckingham palace"
    static func matchableName(from name: String) -> String {
        var result = name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove leading "the "
        if result.hasPrefix("the ") {
            result = String(result.dropFirst(4))
        }

        // Remove parenthetical suffixes: "Name (Something)" → "Name"
        if let parenRange = result.range(of: #"\s*\(.*\)\s*$"#, options: .regularExpression) {
            result = String(result[result.startIndex..<parenRange.lowerBound])
        }

        return result
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Deduplication

    /// Deduplicate POIs by normalised name + coordinate proximity.
    /// When the same POI is found from multiple search circles, keep the first
    /// occurrence (arbitrary but deterministic within a single run).
    private func deduplicate(_ pois: [POI]) -> [POI] {
        var seen: [(name: String, coordinate: CLLocationCoordinate2D)] = []
        var unique: [POI] = []

        for poi in pois {
            let normName = poi.name.lowercased()
            let isDuplicate = seen.contains { existing in
                existing.name == normName &&
                CLLocation(latitude: existing.coordinate.latitude, longitude: existing.coordinate.longitude)
                    .distance(from: CLLocation(latitude: poi.location.latitude, longitude: poi.location.longitude))
                    < Self.deduplicationDistanceMeters
            }

            if !isDuplicate {
                seen.append((name: normName, coordinate: poi.location.clCoordinate))
                unique.append(poi)
            }
        }

        return unique
    }

    // MARK: - Search Point Sampling

    /// Sample the route polyline at regular distance intervals.
    /// Always includes the first waypoint. Same algorithm as
    /// `OverpassPOIDiscoveryService.searchPoints`.
    static func searchPoints(
        along waypoints: [CLLocationCoordinate2D],
        intervalMetres: Double = 500
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

        // Always include the last waypoint so the tail end of the route
        // is covered even when the remaining distance after the last
        // sampled point is shorter than one full interval.
        if let last = waypoints.last,
           points.count > 1,
           let lastSampled = points.last,
           last.distance(to: lastSampled) > intervalMetres * 0.3 {
            points.append(last)
        }

        return points
    }

    // MARK: - Helpers

    /// Stable identifier from name + coordinate for deduplication across sessions.
    private static func stableId(name: String, coordinate: CLLocationCoordinate2D) -> String {
        // Round coordinates to ~11m precision to absorb minor MapKit jitter
        let lat = Int(coordinate.latitude * 10000)
        let lon = Int(coordinate.longitude * 10000)
        let normName = name.lowercased().replacingOccurrences(of: " ", with: "_")
        return "\(normName)_\(lat)_\(lon)"
    }
}
