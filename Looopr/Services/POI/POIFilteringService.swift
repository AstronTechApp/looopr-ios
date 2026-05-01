import CoreLocation

struct POIFilteringService {
    let configuration: AppConfiguration

    init(configuration: AppConfiguration = .current) {
        self.configuration = configuration
    }

    // MARK: - Quality

    /// Check if a food POI meets the 4.4+ rating threshold.
    /// Only applicable to food — attractions always pass.
    ///
    /// POIs from sources without ratings (e.g. OpenStreetMap) are allowed
    /// through if they have a name and a valid food category — the geographic
    /// corridor filter already ensures they're close to the route.
    func foodMeetsQualityThreshold(_ poi: POI) -> Bool {
        guard poi.category.isFood else { return true }

        // If rating data is available, enforce quality thresholds.
        // If not (e.g. OSM data), allow the POI through — corridor proximity
        // and category match are sufficient signals.
        if let rating = poi.rating, let reviewCount = poi.reviewCount {
            let thresholds = configuration.poi.foodThresholds
            guard rating >= thresholds.minRating else { return false }
            guard reviewCount >= thresholds.minReviewCount else { return false }
        }

        // Type validation: ensure Google types match food category
        if !poi.googlePlaceTypes.isEmpty {
            let googleCategory = POICategory.from(googleTypes: poi.googlePlaceTypes)
            if !googleCategory.isFood { return false }
        }

        return true
    }

    // MARK: - Attraction Quality

    /// Check if an attraction POI meets tiered quality thresholds by category.
    /// - Always-keep: parks, gardens, churches, monuments, viewpoints (inherently interesting for walks)
    /// - Standard threshold (4.0+ rating, 30+ reviews): museums, castles, historicSites, zoos, aquariums, theaters
    /// - Higher threshold (4.0+ rating, 100+ reviews): landmarks (high-noise category)
    /// - Galleries: require a Wikidata entry (notability proof) — rejects small
    ///   independent galleries while keeping the National Gallery, Serpentine, etc.
    ///   Galleries that pass are treated as museums for priority/display.
    /// - Reject: .other category
    ///
    /// POIs from sources without ratings (e.g. OpenStreetMap) are allowed
    /// through for all categories except `.other` and `.gallery` without Wikidata.
    func attractionMeetsQualityThreshold(_ poi: POI) -> Bool {
        // Always-keep categories — inherently interesting for walking routes.
        // Parks and churches are landmarks walkers expect to see; filtering
        // them by rating/reviews causes well-known green spaces and historic
        // churches to disappear from the list while still showing on the map.
        let alwaysKeep: Set<POICategory> = [.park, .garden, .church, .monument, .viewpoint]
        if alwaysKeep.contains(poi.category) {
            return true
        }

        // Reject .other — uncategorized POIs are rarely interesting for walkers
        if poi.category == .other {
            return false
        }

        // Galleries: only keep if the OSM element has a Wikidata entry.
        // Major galleries (National Gallery, Tate, Serpentine) always have one;
        // small independent / commercial galleries almost never do. This is a
        // much cleaner signal than rating thresholds for OSM-sourced data where
        // we have no ratings. Galleries that pass are shown alongside museums.
        if poi.category == .gallery {
            return poi.hasWikidata
        }

        // If no rating data is available (e.g. OSM source), allow the POI
        // through — OSM tagging + corridor proximity are sufficient signals.
        // The POI can be enriched on-demand when the user taps it.
        guard let rating = poi.rating else {
            return poi.rating == nil && poi.reviewCount == nil
        }
        guard let reviewCount = poi.reviewCount else { return false }

        // Landmarks are a high-noise category — need stronger quality signal.
        let isHighBar = poi.category == .landmark

        let thresholds = isHighBar
            ? configuration.poi.attractionHighBarThresholds
            : configuration.poi.attractionThresholds

        return rating >= thresholds.minRating && reviewCount >= thresholds.minReviewCount
    }

    // MARK: - Sorting

    /// Sort POIs: attractions first (by category priority, then distance asc, then rating desc), food last (by rating desc).
    func sortPOIs(_ pois: [POI]) -> [POI] {
        pois.sorted { a, b in
            // Attractions before food
            if a.isHighlighted != b.isHighlighted {
                return a.isHighlighted
            }
            // Within attractions: museums/galleries before landmarks before theaters
            if a.isHighlighted && b.isHighlighted {
                let priorityA = a.category.sortPriority
                let priorityB = b.category.sortPriority
                if priorityA != priorityB {
                    return priorityA < priorityB
                }
            }
            // Within same priority: closer to route first
            let distA = a.distanceFromRoute ?? .infinity
            let distB = b.distanceFromRoute ?? .infinity
            if abs(distA - distB) > 50 {
                return distA < distB
            }
            // Same proximity: higher rating first
            return (a.rating ?? 0) > (b.rating ?? 0)
        }
    }
}
