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

    func fetchPOIs(
        nearPolyline polyline: [CLLocationCoordinate2D],
        maxDistance: Double,
        limit: Int
    ) async -> [POI] {
        guard let center = polylineCenter(polyline) else { return [] }

        let cacheKey = "\(Int(center.latitude * 100)),\(Int(center.longitude * 100))"
        if let cached = await cache.get(cacheKey) {
            return Array(cached.prefix(limit))
        }

        // Step 1: Discover raw POIs from Apple Maps
        let rawPOIs: [POI]
        do {
            rawPOIs = try await discovery.discoverPOIs(
                center: center,
                radiusMeters: min(maxDistance * 2, configuration.poi.searchRadiusCapMeters)
            )
        } catch {
            logger.warning("Discovery failed: \(error.localizedDescription)")
            return []
        }

        guard !rawPOIs.isEmpty else { return [] }
        logger.info("Discovered \(rawPOIs.count) raw POIs")

        // Step 2: Deduplicate by name
        let unique = deduplicateByName(rawPOIs)

        // Step 3: Enrich with Google Places (parallel, limited concurrency)
        let enriched = await enrichPOIs(unique)
        logger.info("Enriched \(enriched.count) POIs")

        // Step 4: Filter by quality + proximity to route
        let filtered = filtering.filterAndSort(enriched, nearPolyline: polyline)
        let result = Array(filtered.prefix(limit))

        await cache.set(cacheKey, value: result)
        logger.info("Returning \(result.count) qualified POIs (\(result.filter(\.isHighlighted).count) attractions, \(result.filter { $0.category.isFood }.count) food)")
        return result
    }

    // MARK: - Private

    private func enrichPOIs(_ pois: [POI]) async -> [POI] {
        await withTaskGroup(of: POI?.self) { group in
            for poi in pois.prefix(20) { // Cap API calls
                group.addTask { [enrichment, configuration] in
                    let minRating = poi.category.isFood
                        ? configuration.poi.foodThresholds.minRating
                        : configuration.poi.attractionThresholds.minRating
                    return await enrichment.enrich(poi: poi, minRating: minRating)
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

    private func deduplicateByName(_ pois: [POI]) -> [POI] {
        var seen = Set<String>()
        return pois.filter { poi in
            let key = poi.name.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private func polylineCenter(_ polyline: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !polyline.isEmpty else { return nil }
        let midIndex = polyline.count / 2
        return polyline[midIndex]
    }
}
