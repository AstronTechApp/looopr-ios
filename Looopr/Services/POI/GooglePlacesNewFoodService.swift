import CoreLocation
import Foundation

/// Discovers cafes and restaurants along a route using the **Google Places (New)**
/// Nearby Search endpoint (`POST /v1/places:searchNearby`).
///
/// This service is called **on-demand** when the user taps the "Food & Drinks" tab,
/// NOT during the initial route POI load. Tourist attractions remain on OSM/Overpass.
///
/// Flow:
///   1. Sample search points along the route at ~800m intervals.
///   2. Issue parallel POST requests (one per point, 600m radius each)
///      with `includedTypes: ["cafe", "coffee_shop", "restaurant"]`.
///   3. Deduplicate results by Google `place.id` across all search points.
///   4. **Misclassification filter**: exclude non-food venues (pet groomers,
///      salons, etc.) that Google tags with food types. Uses the full `types`
///      array, `primaryType`, and name heuristics.
///   5. Post-fetch corridor filter: discard places farther than 400m from the route.
///   6. Filter client-side for rating >= 4.5 (falls back to 4.0 if too few results).
///   7. Cap at 10 cafes + 10 restaurants.
///   8. Return POIs with `googleMapsUri` for the "View on Google Maps" link.
///
/// For an 8.3km route this produces ~11 search points × 20 max results = up to
/// 220 raw results, which after dedup + corridor + quality filter typically yields
/// 10-20 high-quality food POIs distributed along the full walk.
actor GooglePlacesNewFoodService {
    private let apiClient: APIClient
    private let apiKey: String
    private let configuration: AppConfiguration
    private let cache: CacheManager<String, [POI]>
    private let logger = AppLogger(category: "FoodSearch")

    /// Preferred minimum rating (tight filter). Falls back to `fallbackRating` if
    /// the tight filter yields fewer than `fallbackThreshold` results.
    private let preferredRating: Double = 4.5
    private let fallbackRating: Double = 4.0
    private let fallbackThreshold = 3
    /// Maximum results per sub-category (cafes, restaurants).
    private let maxPerCategory = 10

    // MARK: - Misclassification Filter

    /// Google Places types that indicate a venue is NOT a food establishment,
    /// even if it also carries a "cafe" or "restaurant" tag. For example,
    /// "Hair Of The Doggy" is a dog grooming salon tagged as "cafe" by Google.
    private static let nonFoodTypeBlocklist: Set<String> = [
        // Pet / animal services
        "pet_store", "pet_care", "veterinary_care",
        // Beauty / personal care
        "beauty_salon", "hair_salon", "hair_care", "spa", "nail_salon",
        // Health / fitness
        "gym", "health", "physiotherapist", "dentist", "doctor", "hospital",
        // Automotive
        "car_wash", "car_repair", "car_dealer",
        // Household services
        "laundry", "dry_cleaning", "electrician", "plumber",
        // Retail (non-food)
        "clothing_store", "shoe_store", "furniture_store", "hardware_store",
        "electronics_store", "book_store",
        // Other non-food
        "real_estate_agency", "travel_agency", "insurance_agency",
        "accounting", "lawyer", "lodging", "campground",
    ]

    /// Google Places primary types that are definitively food-related.
    /// If a place's `primaryType` is NOT in this set, it's likely misclassified.
    private static let foodPrimaryTypes: Set<String> = [
        "restaurant", "cafe", "coffee_shop", "bakery", "bar",
        "meal_takeaway", "meal_delivery", "food",
        "ice_cream_shop", "sandwich_shop", "pizza_restaurant",
        "seafood_restaurant", "steak_house", "sushi_restaurant",
        "breakfast_restaurant", "brunch_restaurant",
        "chinese_restaurant", "indian_restaurant", "italian_restaurant",
        "japanese_restaurant", "korean_restaurant", "mexican_restaurant",
        "thai_restaurant", "turkish_restaurant", "vietnamese_restaurant",
        "middle_eastern_restaurant", "mediterranean_restaurant",
        "american_restaurant", "greek_restaurant", "french_restaurant",
        "spanish_restaurant", "indonesian_restaurant", "lebanese_restaurant",
        "brazilian_restaurant", "ramen_restaurant", "hamburger_restaurant",
        "vegan_restaurant", "vegetarian_restaurant",
    ]

    /// Name substrings that suggest a non-food venue when no food context is present.
    /// Checked case-insensitively. Only applied as a secondary signal alongside
    /// type-based checks, or when `primaryType` is missing/ambiguous.
    private static let nonFoodNameKeywords: [String] = [
        "grooming", "groomers", "pet", "doggy", "dog wash",
        "veterinary", "vet clinic",
        "salon", "barber", "nails", "beauty",
        "car wash", "auto", "laundry", "dry clean",
    ]

    /// Food-related name keywords that override `nonFoodNameKeywords` matches.
    /// Prevents filtering out legitimate places like "Hot Dog Café".
    private static let foodNameKeywords: [String] = [
        "café", "cafe", "coffee", "restaurant", "bistro", "brasserie",
        "bakery", "patisserie", "pizzeria", "kitchen", "diner",
        "grill", "sushi", "noodle", "burger", "taco", "sandwich",
        "tea room", "tea house", "juice", "smoothie", "ice cream",
        "hot dog", "food", "eat", "brunch",
    ]

    /// Returns `true` if the place appears to be misclassified — i.e. NOT actually
    /// a food establishment despite having a food-related `includedType` match.
    private static func isMisclassifiedNonFood(_ place: GooglePlacesAPI.NewPlace) -> Bool {
        let types = Set(place.types ?? [])

        // 1. Check if any type in the full types array is on the non-food blocklist.
        //    A pet groomer tagged as "cafe" will also have "pet_care" in its types.
        if !types.isDisjoint(with: nonFoodTypeBlocklist) {
            return true
        }

        // 2. Check primaryType — if it exists and is NOT a food type, reject.
        //    Google Places (New) returns a single primaryType that represents what
        //    the place *actually* is. A grooming salon's primaryType would be
        //    "pet_care" or "beauty_salon", not "cafe".
        if let primary = place.primaryType, !primary.isEmpty {
            if !foodPrimaryTypes.contains(primary) {
                return true
            }
        }

        // 3. Name-based heuristic (secondary signal).
        //    Only triggers if the name contains non-food keywords AND does NOT
        //    contain food keywords. This catches edge cases where type data is
        //    incomplete but the name is a clear giveaway.
        let nameLower = (place.displayName?.text ?? "").lowercased()
        let hasNonFoodName = nonFoodNameKeywords.contains { nameLower.contains($0) }
        if hasNonFoodName {
            let hasFoodName = foodNameKeywords.contains { nameLower.contains($0) }
            if !hasFoodName {
                return true
            }
        }

        return false
    }

    init(
        apiClient: APIClient,
        apiKey: String,
        configuration: AppConfiguration = .current
    ) {
        self.apiClient = apiClient
        self.apiKey = apiKey
        self.configuration = configuration
        self.cache = CacheManager(ttl: configuration.poi.googlePlacesCacheTTLSeconds)
    }

    // MARK: - Public API

    /// Fetch cafes and restaurants near the given route polyline.
    ///
    /// Makes **multiple** Google Places (New) Nearby Search calls at points
    /// sampled along the route, deduplicates by place ID, filters by rating,
    /// and caps results. This ensures full route coverage even for long walks
    /// (the previous single-center approach missed 60%+ of routes over 3km).
    func fetchFoodPOIs(
        nearPolyline polyline: [CLLocationCoordinate2D],
        departureDate: Date? = nil
    ) async -> [POI] {
        guard !polyline.isEmpty else { return [] }

        // Cache key based on route geometric center (rounded to ~1km grid)
        let geoCentroid = geometricCentroid(polyline)
        let cacheKey = "food:\(Int(geoCentroid.latitude * 100)),\(Int(geoCentroid.longitude * 100)):\(Self.departureCacheKey(departureDate))"
        if let cached = await cache.get(cacheKey) {
            logger.info("Returning \(cached.count) cached food POIs")
            return cached
        }

        // Sample search points along the route at ~800m intervals.
        // Each Google Places call returns max 20 results within its radius,
        // so we need multiple overlapping circles to cover the full route.
        let searchPoints = Self.foodSearchPoints(along: polyline, intervalMetres: 800)
        let perPointRadius: Double = 600  // 600m radius per point — overlaps with 800m spacing

        logger.info("Searching food at \(searchPoints.count) points along route (radius \(Int(perPointRadius))m each)")

        // Parallel API calls for all search points
        let allPlaces: [GooglePlacesAPI.NewPlace] = await withTaskGroup(of: [GooglePlacesAPI.NewPlace].self) { group in
            for point in searchPoints {
                group.addTask { [apiClient, apiKey, logger] in
                    let endpoint = GooglePlacesAPI.nearbySearchNew(
                        latitude: point.latitude,
                        longitude: point.longitude,
                        radiusMeters: perPointRadius,
                        includedTypes: ["cafe", "coffee_shop", "restaurant"],
                        maxResultCount: 20,
                        apiKey: apiKey
                    )

                    do {
                        let (data, httpResponse) = try await apiClient.requestRaw(endpoint)

                        guard (200...299).contains(httpResponse.statusCode) else {
                            let body = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
                            logger.error("Google Places (New) HTTP \(httpResponse.statusCode) at (\(String(format: "%.4f", point.latitude)),\(String(format: "%.4f", point.longitude))): \(body)")
                            return []
                        }

                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase

                        let response = try decoder.decode(
                            GooglePlacesAPI.NearbySearchNewResponse.self,
                            from: data
                        )
                        return response.places ?? []
                    } catch {
                        logger.error("Google Places (New) food search failed at (\(String(format: "%.4f", point.latitude)),\(String(format: "%.4f", point.longitude))): \(error)")
                        return []
                    }
                }
            }

            var results: [GooglePlacesAPI.NewPlace] = []
            for await batch in group {
                results.append(contentsOf: batch)
            }
            return results
        }

        // Deduplicate by place ID across all search points
        var seenIds = Set<String>()
        let places = allPlaces.filter { place in
            guard let id = place.id, !seenIds.contains(id) else { return false }
            seenIds.insert(id)
            return true
        }

        logger.info("Google Places (New) returned \(allPlaces.count) raw results → \(places.count) unique after dedup")

        // ── Misclassification filter ──
        // Google Places sometimes tags non-food venues (pet groomers, salons, etc.)
        // with food types like "cafe". Filter these out by checking the full types
        // array, primaryType, and name heuristics.
        let validFoodPlaces = places.filter { place in
            let dominated = Self.isMisclassifiedNonFood(place)
            if dominated {
                logger.info("Filtered misclassified non-food place: \"\(place.displayName?.text ?? "?")\" (primaryType: \(place.primaryType ?? "nil"), types: \(place.types ?? []))")
            }
            return !dominated
        }
        logger.info("After misclassification filter: \(validFoodPlaces.count) places (excluded \(places.count - validFoodPlaces.count) non-food)")

        // Convert to POIs
        let allPOIs = validFoodPlaces.compactMap { place -> POI? in
            guard let name = place.displayName?.text, !name.isEmpty,
                  let lat = place.location?.latitude,
                  let lng = place.location?.longitude else { return nil }

            // Determine category from primaryType.
            // Google Places (New) may return "coffee_shop" instead of "cafe" as the
            // primaryType — both must map to .cafe to match POICategory.from(googleTypes:).
            let category: POICategory
            switch place.primaryType {
            case "cafe", "coffee_shop": category = .cafe
            case "restaurant": category = .restaurant
            case "bakery": category = .bakery
            default: category = .restaurant
            }

            // Build Google Maps URL
            var mapsURL: URL?
            if let uriString = place.googleMapsUri {
                mapsURL = URL(string: uriString)
            }

            // Map weekdayDescriptions to the format expected by the app.
            // Google Places (New) format: ["Monday: 9:00 AM – 5:00 PM", ...]
            // This matches the POI model's openingHoursWeekdayText array.
            let weekdayText = place.regularOpeningHours?.weekdayDescriptions
            let openingPeriods = place.regularOpeningHours?.periods?.compactMap(Self.openingHoursPeriod)

            return POI(
                name: name,
                location: Location(CLLocationCoordinate2D(latitude: lat, longitude: lng)),
                category: category,
                rating: place.rating,
                openingHoursWeekdayText: weekdayText,
                openingHoursPeriods: openingPeriods,
                isOpenNow: place.regularOpeningHours?.openNow,
                googlePlaceTypes: place.types ?? place.primaryType.map { [$0] } ?? [],
                googlePlaceId: place.id,
                isEnriched: false,
                googleMapsUri: mapsURL
            )
        }

        logger.info("Parsed \(allPOIs.count) food POIs from \(validFoodPlaces.count) API results")

        // ── Post-fetch corridor filter ──
        // The API search circle is intentionally wide to cover the full route,
        // but that can return places far from the actual walking path. Discard
        // any result whose minimum distance to the route polyline exceeds the
        // configured food max distance (250m). Also compute `distanceFromRoute`
        // for each POI so the card can display it.
        let maxFoodDistance = configuration.poi.foodMaxDistanceMeters
        let corridorFiltered = allPOIs.compactMap { poi -> POI? in
            let distance = RouteGeometry.minimumDistance(
                from: poi.location.clCoordinate,
                toPolyline: polyline
            )
            guard distance <= maxFoodDistance else { return nil }
            var filtered = poi
            filtered.distanceFromRoute = distance
            return filtered
        }
        logger.info("After corridor filter (<= \(Int(maxFoodDistance))m from route): \(corridorFiltered.count) food POIs (discarded \(allPOIs.count - corridorFiltered.count))")

        // ── Rating filter with fallback ──
        // Prefer 4.5+ but if that yields fewer than 3 results, widen to 4.0+.
        var qualityFiltered = corridorFiltered.filter { ($0.rating ?? 0) >= preferredRating }
        if qualityFiltered.count < fallbackThreshold {
            logger.info("Only \(qualityFiltered.count) POIs with rating >= \(preferredRating), falling back to >= \(fallbackRating)")
            qualityFiltered = corridorFiltered.filter { ($0.rating ?? 0) >= fallbackRating }
        }
        logger.info("After rating filter: \(qualityFiltered.count) food POIs")

        // ── Split & cap ──
        let cafes = Array(
            qualityFiltered
                .filter { $0.category == .cafe || $0.category == .bakery }
                .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
                .prefix(maxPerCategory)
        )
        let restaurants = Array(
            qualityFiltered
                .filter { $0.category == .restaurant || $0.category == .bar }
                .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
                .prefix(maxPerCategory)
        )

        let result = cafes + restaurants
        await cache.set(cacheKey, value: result)
        logger.info("Returning \(result.count) food POIs (\(cafes.count) cafes, \(restaurants.count) restaurants)")
        return result
    }

    // MARK: - Private Helpers

    private static func openingHoursPeriod(
        from period: GooglePlacesAPI.Period
    ) -> OpeningHoursPeriod? {
        guard let open = period.open,
              let openHour = open.hour,
              let openMinute = open.minute
        else {
            return nil
        }

        return OpeningHoursPeriod(
            openDay: open.day,
            openHour: openHour,
            openMinute: openMinute,
            closeDay: period.close?.day,
            closeHour: period.close?.hour,
            closeMinute: period.close?.minute
        )
    }

    private static func departureCacheKey(_ departureDate: Date?) -> String {
        guard let departureDate else { return "now" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter.string(from: departureDate)
    }

    /// Geometric centroid (average lat/lon) — used only for cache key generation.
    /// Unlike the old `polylineCenter` (which picked the midpoint index and landed
    /// on the route perimeter), this produces a point near the loop's interior.
    private func geometricCentroid(_ polyline: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let sumLat = polyline.reduce(0.0) { $0 + $1.latitude }
        let sumLon = polyline.reduce(0.0) { $0 + $1.longitude }
        let count = Double(polyline.count)
        return CLLocationCoordinate2D(latitude: sumLat / count, longitude: sumLon / count)
    }

    /// Sample the route polyline at regular distance intervals for food search.
    /// Always includes the first and last points. Same algorithm as
    /// `OverpassPOIDiscoveryService.searchPoints` but with wider spacing
    /// (one Google API call per point, so we want fewer points).
    static func foodSearchPoints(
        along waypoints: [CLLocationCoordinate2D],
        intervalMetres: Double = 800
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

        // Ensure the last point is included for loop routes
        // (the start and end may coincide, but that's handled by dedup)
        if let last = waypoints.last, points.count > 1 {
            let lastPoint = points.last!
            let distToLast = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude))
            if distToLast > intervalMetres * 0.3 {
                points.append(last)
            }
        }

        return points
    }
}
