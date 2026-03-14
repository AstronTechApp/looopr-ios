import CoreLocation

struct POIFilteringService {
    let configuration: AppConfiguration

    init(configuration: AppConfiguration = .current) {
        self.configuration = configuration
    }

    func meetsQualityThreshold(_ poi: POI) -> Bool {
        let thresholds = poi.category.isFood
            ? configuration.poi.foodThresholds
            : configuration.poi.attractionThresholds

        guard let rating = poi.rating, rating >= thresholds.minRating else { return false }
        guard let reviewCount = poi.reviewCount, reviewCount >= thresholds.minReviewCount else { return false }

        // Type validation: ensure Google types match our category
        if !poi.googlePlaceTypes.isEmpty {
            let googleCategory = POICategory.from(googleTypes: poi.googlePlaceTypes)
            if poi.category.isFood && !googleCategory.isFood { return false }
            if poi.category.isTouristAttraction && !googleCategory.isTouristAttraction && googleCategory != .other {
                return false
            }
        }

        return true
    }

    func filterAndSort(_ pois: [POI], nearPolyline polyline: [CLLocationCoordinate2D]) -> [POI] {
        let maxDistance = configuration.poi.maxDistanceFromRouteMeters

        let nearbyPOIs = pois.filter { poi in
            let dist = RouteGeometry.minimumDistance(
                from: poi.location.clCoordinate,
                toPolyline: polyline
            )
            return dist <= maxDistance
        }

        let qualified = nearbyPOIs.filter { meetsQualityThreshold($0) }

        // Sort: attractions first (by rating desc), then food (by rating desc)
        return qualified.sorted { a, b in
            if a.isHighlighted != b.isHighlighted {
                return a.isHighlighted
            }
            return (a.rating ?? 0) > (b.rating ?? 0)
        }
    }
}
