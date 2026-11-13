import CoreLocation

actor POIAggregatorService {
    private let discovery: POIDiscovering
    private let enrichment: POIEnriching
    private let filtering: POIFilteringService
    private let configuration: AppConfiguration
    private let cache: CacheManager<String, [POI]>
    private let logger = AppLogger(category: "POIAggregator")

    init(
        discovery: POIDiscovering? = nil,
        enrichment: POIEnriching? = nil,
        configuration: AppConfiguration = .current
    ) {
        self.discovery = discovery ?? ServiceContainer.shared.resolve(POIDiscovering.self)
        self.enrichment = enrichment ?? ServiceContainer.shared.resolve(POIEnriching.self)
        self.configuration = configuration
        self.filtering = POIFilteringService(configuration: configuration)
        self.cache = CacheManager(ttl: configuration.poi.cacheTTLSeconds)
    }

    /// Sights (and, from discovery, any food) along a loop.
    ///
    /// - `onPartialResults` receives a first, processed list while throttled
    ///   searches are still being retried, so the screen can show it early.
    /// - Throws `POIError.searchUnavailable` when searches failed and nothing
    ///   was found; returns `[]` only when the searches worked and there is
    ///   genuinely nothing along the route.
    /// - Successful results are cached per loop (see `cacheKey(for:)`) for
    ///   `configuration.poi.cacheTTLSeconds`, so reopening a loop shows the
    ///   same sights without searching again. Failures are never cached.
    func fetchPOIs(
        nearPolyline polyline: [CLLocationCoordinate2D],
        maxDistance: Double,
        limit: Int,
        onPartialResults: (@Sendable ([POI]) async -> Void)? = nil
    ) async throws -> [POI] {
        guard let cacheKey = Self.cacheKey(for: polyline) else { return [] }
        if let cached = await cache.get(cacheKey) {
            return cached
        }

        // Step 1: Discover POIs along the route corridor.
        logger.info("Starting POI aggregation for route with \(polyline.count) waypoints, maxDistance=\(Int(maxDistance))m, limit=\(limit)")
        let rawPOIs: [POI]
        do {
            rawPOIs = try await discovery.discoverPOIs(
                alongRoute: polyline,
                searchIntervalMeters: configuration.poi.searchIntervalMeters,
                searchRadiusMeters: configuration.poi.searchRadiusPerPointMeters,
                onPartialResults: onPartialResults.map { forward in
                    { @Sendable [weak self] (partial: [POI]) async in
                        guard let self, !partial.isEmpty else { return }
                        let processed = await self.process(partial, polyline: polyline, limit: limit)
                        await forward(processed)
                    }
                }
            )
        } catch POIError.searchUnavailable {
            logger.warning("⚠️ Sight search unavailable (searches failed, nothing found)")
            throw POIError.searchUnavailable
        } catch {
            logger.warning("⚠️ Discovery failed: \(error.localizedDescription) — returning 0 POIs")
            return []
        }

        guard !rawPOIs.isEmpty else {
            logger.info("Discovery returned 0 POIs — searches succeeded, nothing along this route")
            await cache.set(cacheKey, value: [])
            return []
        }

        let result = process(rawPOIs, polyline: polyline, limit: limit)
        await cache.set(cacheKey, value: result)
        return result
    }

    /// Cache key for one loop: the number of waypoints plus its first, middle
    /// and last coordinates at ~1 m precision. Two different loops never
    /// share a key (the old key was the loop's middle point rounded to
    /// 0.01°, about 1 km, so nearby loops could share one cached list).
    static func cacheKey(for polyline: [CLLocationCoordinate2D]) -> String? {
        guard let first = polyline.first, let last = polyline.last else { return nil }
        let middle = polyline[polyline.count / 2]
        func fmt(_ c: CLLocationCoordinate2D) -> String {
            "\(Int((c.latitude * 100_000).rounded())),\(Int((c.longitude * 100_000).rounded()))"
        }
        return "\(polyline.count)|\(fmt(first))|\(fmt(middle))|\(fmt(last))"
    }

    /// Steps 2–7: dedupe, corridor filter, quality filter, spatial selection.
    private func process(
        _ rawPOIs: [POI],
        polyline: [CLLocationCoordinate2D],
        limit: Int
    ) -> [POI] {
        logger.info("Discovered \(rawPOIs.count) raw POIs")

        // Step 2: Deduplicate by place_id
        let unique = deduplicateByPlaceId(rawPOIs)

        // Step 3: Filter by proximity + compute distance from route.
        // Distance is computed as minimum distance to the nearest route segment
        // (not from user, not from start point).
        // Both attractions and food use the same corridor width so that
        // restaurants on side streets are not excluded from quieter sections.
        let nearbyWithDistance = computeDistancesAndFilter(unique, polyline: polyline)
        logger.info("After proximity filter: \(nearbyWithDistance.count) POIs near route")

        // Step 4: Split into attractions and food, then sort each group
        // by position along the route polyline so that the enrichment
        // prefix captures POIs distributed across the full loop — not
        // just the ones nearest the start.
        let nearbyAttractions = sortByRoutePosition(
            nearbyWithDistance.filter { $0.category.isTouristAttraction },
            polyline: polyline
        )
        let nearbyFood = sortByRoutePosition(
            nearbyWithDistance.filter { $0.category.isFood },
            polyline: polyline
        )
        logger.info("Split: \(nearbyAttractions.count) attractions, \(nearbyFood.count) food within range")

        // Step 5: Attractions are NOT enriched with Google Place Details.
        // MapKit provides name, location, category, website, and phone —
        // sufficient for the attraction card (no star rating needed).
        // This eliminates ~$0.025 per POI in Google Places API costs.
        // On-demand enrichment when the user taps is also skipped for
        // attractions; only food POIs use Google Places enrichment.
        let attractions = nearbyAttractions
        logger.info("Using \(attractions.count) MapKit-sourced attractions (no Google enrichment)")

        // Step 5c: Filter attractions by quality — tiered thresholds by category.
        // Parks, gardens, churches, monuments, and viewpoints always pass.
        // Museums, castles, zoos etc. need 4.0+ rating and 30+ reviews.
        // Landmarks and galleries need 4.0+ rating and 100+ reviews (high noise category).
        let qualifiedAttractions = attractions.filter { filtering.attractionMeetsQualityThreshold($0) }
        logger.info("Qualified attractions after quality filter: \(qualifiedAttractions.count) (from \(attractions.count) discovered)")

        // Step 6: Filter food by quality (4.4+ rating, 5+ reviews) using
        // discovery data — Nearby Search returns the same rating/reviewCount
        // as Place Details, so the quality filter produces identical results.
        let qualifiedFood = nearbyFood.filter { filtering.foodMeetsQualityThreshold($0) }
        logger.info("Qualified food after rating filter: \(qualifiedFood.count) (from \(nearbyFood.count) discovered, no Place Details calls)")

        // Step 7: Select attractions with spatial distribution guarantee.
        //
        // The route is divided into equal-length segments and POIs are
        // selected from each segment proportionally so every section of the
        // walk has attractions — not just the area with the densest cluster.
        //
        // Within each segment, higher-priority tiers are preferred:
        //   0 — Landmarks / tourist attractions
        //   1 — Parks, gardens, viewpoints
        //   2 — Museums, galleries (with Wikidata), castles, historic sites
        //   3 — Churches, monuments
        //   4 — Theaters, zoos, aquariums
        let selectedAttractions = Self.selectWithSpatialDistribution(
            qualifiedAttractions,
            limit: limit,
            polyline: polyline,
            logger: logger
        )
        let sortedAttractions = sortByRoutePosition(selectedAttractions, polyline: polyline)
        let sortedFood = sortByRoutePosition(qualifiedFood, polyline: polyline)
        let result = sortedAttractions + sortedFood
        logger.info("Selected \(sortedAttractions.count) attractions (spatially distributed) from \(qualifiedAttractions.count) qualified")
        logger.info("Returning \(result.count) qualified POIs (\(sortedAttractions.count) attractions, \(sortedFood.count) food)")
        return result
    }

    // MARK: - Private

    /// Google Place types that indicate a result is NOT a tourist attraction.
    /// Used as a second-pass filter after enrichment reveals the true nature of a POI
    /// (e.g., a "castle"-named shop that Apple Maps doesn't tag as .store).
    private static let nonAttractionGoogleTypes: Set<String> = [
        "store", "clothing_store", "shoe_store", "jewelry_store",
        "furniture_store", "electronics_store", "hardware_store",
        "home_goods_store", "shopping_mall", "convenience_store",
        "department_store", "supermarket", "grocery_or_supermarket",
        "lodging", "real_estate_agency", "insurance_agency",
        "travel_agency", "car_dealer", "car_rental", "car_repair",
        "car_wash", "gas_station", "moving_company",
        "lawyer", "accounting", "dentist", "doctor", "hospital",
        "veterinary_care", "physiotherapist",
        "hair_care", "beauty_salon", "spa",
        "gym", "laundry", "locksmith", "plumber", "electrician",
        "roofing_contractor", "painter", "general_contractor",
        "storage", "pet_store",
    ]

    // MARK: - Spatially-Distributed Selection

    /// Number of equal-length segments to divide the route into for spatial
    /// distribution. Each segment gets a proportional share of the POI budget
    /// so that attractions are spread along the entire walk.
    private static let spatialSegmentCount = 5

    /// Select up to `limit` POIs ensuring they are spread across the full
    /// route, not clustered in one area.
    ///
    /// **Algorithm:**
    /// 1. Divide the route polyline into `spatialSegmentCount` equal-length
    ///    segments based on cumulative distance.
    /// 2. Assign each POI to its segment using `distanceAlongRoute`.
    /// 3. Allocate slots to segments proportionally to how many POIs they
    ///    contain, with a guaranteed minimum of 1 slot per non-empty segment.
    /// 4. Within each segment, select POIs by priority tier (landmarks first,
    ///    then parks, museums, etc.), shuffling within each tier.
    /// 5. Any leftover slots (from segments with fewer POIs than their
    ///    allocation) are redistributed to segments that have surplus.
    ///
    /// This guarantees that a 16.9 km Amsterdam loop shows POIs from the
    /// north, west, south, AND east — not just the cluster near Centraal.
    private static func selectWithSpatialDistribution(
        _ pois: [POI],
        limit: Int,
        polyline: [CLLocationCoordinate2D],
        logger: AppLogger
    ) -> [POI] {
        guard pois.count > limit else { return pois }
        guard polyline.count >= 2 else {
            return selectByPriorityThenRandom(pois, limit: limit)
        }

        // 1. Compute total route length.
        var totalRouteLength: Double = 0
        for i in 1..<polyline.count {
            totalRouteLength += polyline[i - 1].distance(to: polyline[i])
        }
        guard totalRouteLength > 0 else {
            return selectByPriorityThenRandom(pois, limit: limit)
        }

        let segmentLength = totalRouteLength / Double(spatialSegmentCount)

        // 2. Assign each POI to a segment based on distanceAlongRoute.
        var segments: [[POI]] = Array(repeating: [], count: spatialSegmentCount)
        for poi in pois {
            let distance = poi.distanceAlongRoute ?? 0
            var segmentIndex = Int(distance / segmentLength)
            // Clamp to valid range (last point lands exactly on boundary)
            segmentIndex = min(segmentIndex, spatialSegmentCount - 1)
            segmentIndex = max(segmentIndex, 0)
            segments[segmentIndex].append(poi)
        }

        let nonEmptyCount = segments.filter { !$0.isEmpty }.count
        logger.info("Spatial distribution: \(pois.count) POIs across \(nonEmptyCount)/\(spatialSegmentCount) segments, route length \(Int(totalRouteLength))m")
        for (i, seg) in segments.enumerated() {
            logger.debug("  Segment \(i) (\(Int(Double(i) * segmentLength))-\(Int(Double(i + 1) * segmentLength))m): \(seg.count) POIs")
        }

        // 3. Allocate slots proportionally with a guaranteed minimum per
        //    non-empty segment.
        var slotAllocations = allocateSlots(
            segmentCounts: segments.map(\.count),
            totalSlots: limit
        )

        // 4. Select within each segment by priority tier.
        var selected: [POI] = []
        var overflow: [POI] = []  // POIs from segments with surplus after allocation

        for (i, segment) in segments.enumerated() {
            let allocation = slotAllocations[i]
            let picked = selectByPriorityThenRandom(segment, limit: allocation)
            selected.append(contentsOf: picked)

            // Track unpicked POIs for redistribution.
            if picked.count < allocation {
                // Segment had fewer POIs than its allocation — unused slots
                // will be redistributed below.
                slotAllocations[i] = picked.count
            }
            if picked.count < segment.count {
                // This segment had more POIs than we could pick — they're
                // available for redistribution if other segments have surplus slots.
                let pickedSet = Set(picked.map { $0.googlePlaceId ?? $0.name })
                overflow.append(contentsOf: segment.filter { !(pickedSet.contains($0.googlePlaceId ?? $0.name)) })
            }
        }

        // 5. Redistribute unused slots from under-populated segments.
        let remaining = limit - selected.count
        if remaining > 0 && !overflow.isEmpty {
            let extra = selectByPriorityThenRandom(overflow, limit: remaining)
            selected.append(contentsOf: extra)
            logger.debug("Redistributed \(extra.count) POIs from overflow to fill \(remaining) remaining slots")
        }

        logger.info("Spatial selection: \(selected.count) POIs selected (limit \(limit))")
        return selected
    }

    /// Allocate `totalSlots` across segments proportionally to their POI
    /// counts, guaranteeing at least 1 slot per non-empty segment.
    private static func allocateSlots(
        segmentCounts: [Int],
        totalSlots: Int
    ) -> [Int] {
        let nonEmptyIndices = segmentCounts.indices.filter { segmentCounts[$0] > 0 }
        guard !nonEmptyIndices.isEmpty else {
            return Array(repeating: 0, count: segmentCounts.count)
        }

        let totalPOIs = segmentCounts.reduce(0, +)
        var allocations = Array(repeating: 0, count: segmentCounts.count)

        // Guarantee 1 slot per non-empty segment.
        let guaranteedSlots = min(nonEmptyIndices.count, totalSlots)
        let remainingSlots = totalSlots - guaranteedSlots

        for i in nonEmptyIndices {
            allocations[i] = 1
        }

        // Distribute remaining slots proportionally.
        if remainingSlots > 0 && totalPOIs > 0 {
            var distributed = 0
            for i in nonEmptyIndices {
                let proportion = Double(segmentCounts[i]) / Double(totalPOIs)
                let extra = Int((proportion * Double(remainingSlots)).rounded())
                allocations[i] += extra
                distributed += extra
            }
            // Fix rounding errors — add/remove from the largest segment.
            let diff = remainingSlots - distributed
            if diff != 0, let largest = nonEmptyIndices.max(by: { segmentCounts[$0] < segmentCounts[$1] }) {
                allocations[largest] += diff
            }
        }

        // Cap each segment's allocation at its actual POI count.
        for i in segmentCounts.indices {
            allocations[i] = min(allocations[i], segmentCounts[i])
        }

        return allocations
    }

    /// Select up to `limit` POIs using priority tiers, filling higher-priority
    /// categories first. Within each tier, POIs are **shuffled** so the
    /// selection is not biased toward the route start.
    ///
    /// Used as the within-segment selection strategy by
    /// `selectWithSpatialDistribution`, and as a fallback when the polyline
    /// is too short for spatial segmentation.
    private static func selectByPriorityThenRandom(_ pois: [POI], limit: Int) -> [POI] {
        guard pois.count > limit else { return pois }

        // Group by priority tier
        var tiers: [Int: [POI]] = [:]
        for poi in pois {
            tiers[poi.category.selectionPriority, default: []].append(poi)
        }

        var selected: [POI] = []
        let sortedTierKeys = tiers.keys.sorted()

        for tier in sortedTierKeys {
            guard selected.count < limit else { break }
            // Stable pseudo-random order (not `shuffle()`): sights now arrive
            // in several updates while the screen is open, and a fresh
            // shuffle each time would reorder the list under the user.
            let tierPOIs = (tiers[tier] ?? []).sorted { Self.stableOrder($0) < Self.stableOrder($1) }

            let remaining = limit - selected.count
            selected.append(contentsOf: tierPOIs.prefix(remaining))
        }

        return selected
    }

    /// FNV-1a hash of the place name: a fixed, evenly spread order that
    /// doesn't favour the route start or the alphabet.
    static func stableOrder(_ poi: POI) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in poi.name.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    // MARK: - Route Position Sorting

    /// Sort POIs by their position along the route polyline (start -> end).
    /// This ensures that enrichment prefix limits and display limits capture
    /// POIs distributed across the full loop, not clustered at the start.
    private func sortByRoutePosition(
        _ pois: [POI],
        polyline: [CLLocationCoordinate2D]
    ) -> [POI] {
        guard polyline.count >= 2 else { return pois }

        return pois.sorted { a, b in
            let aIndex = nearestWaypointIndex(for: a.location.clCoordinate, in: polyline)
            let bIndex = nearestWaypointIndex(for: b.location.clCoordinate, in: polyline)
            if aIndex != bIndex {
                return aIndex < bIndex
            }
            // Tie-break: higher rating first
            return (a.rating ?? 0) > (b.rating ?? 0)
        }
    }

    /// Finds the index of the closest waypoint in the polyline to a coordinate.
    private func nearestWaypointIndex(
        for coordinate: CLLocationCoordinate2D,
        in waypoints: [CLLocationCoordinate2D]
    ) -> Int {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var minDistance = Double.infinity
        var nearestIndex = 0

        for (index, waypoint) in waypoints.enumerated() {
            let waypointLocation = CLLocation(latitude: waypoint.latitude, longitude: waypoint.longitude)
            let distance = location.distance(from: waypointLocation)
            if distance < minDistance {
                minDistance = distance
                nearestIndex = index
            }
        }
        return nearestIndex
    }

    /// Compute the distance from route for each POI, and filter by the corridor threshold.
    /// Both attractions and food use `maxDistanceFromRouteMeters` (500m) so that
    /// restaurants on side streets in quieter route sections are not excluded.
    ///
    /// Distance is computed as the minimum distance from the POI coordinate to the
    /// nearest route segment — not from the user's current position.
    private func computeDistancesAndFilter(
        _ pois: [POI],
        polyline: [CLLocationCoordinate2D]
    ) -> [POI] {
        let maxAllowed = configuration.poi.maxDistanceFromRouteMeters

        return pois.compactMap { poi in
            let distance = RouteGeometry.minimumDistance(
                from: poi.location.clCoordinate,
                toPolyline: polyline
            )
            guard distance <= maxAllowed else { return nil }

            var result = poi
            result.distanceFromRoute = distance
            result.distanceAlongRoute = RouteGeometry.distanceAlongRoute(
                to: poi.location.clCoordinate,
                polyline: polyline
            )
            return result
        }
    }

    /// Enrich attractions with Google Places data. Best-effort: if enrichment fails
    /// for a POI, we keep the original data so the attraction still appears.
    ///
    /// OSM-sourced POIs (identified by "osm:" prefix) are skipped during batch
    /// enrichment to avoid unnecessary Google API calls. They can still be
    /// enriched on-demand when the user taps them.
    ///
    /// Uses even distribution when capping to avoid enriching only POIs near
    /// the route start.
    private func enrichAttractions(_ pois: [POI], cap: Int) async -> [POI] {
        let toEnrich = Self.selectByPriorityThenRandom(pois, limit: cap)
        return await withTaskGroup(of: POI.self) { group in
            for poi in toEnrich {
                // Skip batch enrichment for OSM-sourced POIs — they'd each
                // require a Find Place + Place Details call (~$0.07 per POI).
                // On-demand enrichment (user tap) still works via the
                // enrichment service's findPlaceId fallback.
                if poi.googlePlaceId?.hasPrefix("osm:") == true {
                    group.addTask { poi }
                    continue
                }
                group.addTask { [enrichment] in
                    // No minRating filter for attractions — they always appear
                    if var enriched = await enrichment.enrich(poi: poi, minRating: nil) {
                        enriched.distanceFromRoute = poi.distanceFromRoute
                        enriched.distanceAlongRoute = poi.distanceAlongRoute
                        return enriched
                    }
                    // Keep attraction with discovery data even without enrichment
                    return poi
                }
            }

            var results: [POI] = []
            for await poi in group {
                results.append(poi)
            }
            return results
        }
    }

    /// Enrich food POIs with Google Places data. Strict: if enrichment fails,
    /// the POI is dropped (we need rating data to filter by quality).
    private func enrichFood(_ pois: [POI], cap: Int) async -> [POI] {
        await withTaskGroup(of: POI?.self) { group in
            for poi in pois.prefix(cap) {
                group.addTask { [enrichment, configuration] in
                    let minRating = configuration.poi.foodThresholds.minRating
                    if var enriched = await enrichment.enrich(poi: poi, minRating: minRating) {
                        enriched.distanceFromRoute = poi.distanceFromRoute
                        enriched.distanceAlongRoute = poi.distanceAlongRoute
                        return enriched
                    }
                    return nil
                }
            }

            var results: [POI] = []
            for await enrichedPOI in group {
                if let poi = enrichedPOI {
                    results.append(poi)
                }
            }
            return results
        }
    }

    /// Deduplicate strictly by Google `place_id`.
    /// Co-located venues with different place_ids (e.g. a bakery inside a cafe)
    /// are preserved as independent entries. Falls back to name dedup for POIs
    /// without a place_id (e.g. from Apple Maps fallback).
    private func deduplicateByPlaceId(_ pois: [POI]) -> [POI] {
        var seenPlaceIds = Set<String>()
        var seenNames = Set<String>()

        return pois.filter { poi in
            // Primary key: Google place_id (unique per venue)
            if let placeId = poi.googlePlaceId {
                guard !seenPlaceIds.contains(placeId) else { return false }
                seenPlaceIds.insert(placeId)
                return true
            }
            // Fallback for POIs without a place_id: deduplicate by name only
            let key = poi.name.lowercased()
            guard !seenNames.contains(key) else { return false }
            seenNames.insert(key)
            return true
        }
    }

}
