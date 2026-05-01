import Foundation

actor GooglePlacesEnrichmentService: POIEnriching {
    private let apiClient: APIClient
    private let apiKey: String
    private let configuration: AppConfiguration
    private let logger = AppLogger(category: "GooglePlaces")
    private let cache: CacheManager<String, POI>

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

    func enrich(poi: POI, minRating: Double?) async -> POI? {
        // Check cache
        if let cached = await cache.get(poi.name) {
            return cached
        }

        // Step 1: Find Google Place ID — reuse existing if available from discovery.
        // Non-Google IDs have synthetic prefixes that aren't valid Place IDs:
        //   - "osm:..."    — OpenStreetMap (Overpass) sourced POIs
        //   - "mapkit:..." — Apple MapKit (MKLocalSearch) sourced POIs
        // Both fall through to findPlaceId which searches by name + location.
        let placeId: String
        if let existingId = poi.googlePlaceId,
           !existingId.hasPrefix("osm:"),
           !existingId.hasPrefix("mapkit:") {
            placeId = existingId
        } else {
            guard let foundId = await findPlaceId(for: poi) else {
                logger.debug("No Google Place ID for: \(poi.name)")
                return nil
            }
            placeId = foundId
        }

        // Step 2: Fetch place details
        guard let details = await fetchDetails(placeId: placeId) else {
            return nil
        }

        // Step 3: Apply rating filter
        if let minRating, let rating = details.rating, rating < minRating {
            logger.debug("\(poi.name) rating \(rating) below min \(minRating)")
            return nil
        }

        // Step 4: Build enriched POI
        var enriched = poi

        // Correct the name if Google Places returns a different venue name.
        // Apple Maps sometimes returns temporary event names (e.g., "On TraXS"
        // instead of "Spoorwegmuseum"). If Google's name differs and the place
        // types suggest an establishment, prefer Google's name.
        if let googleName = details.name,
           !googleName.isEmpty,
           googleName.lowercased() != poi.name.lowercased(),
           let types = details.types,
           !Set(types).isDisjoint(with: [
               "museum", "tourist_attraction", "park", "zoo", "aquarium",
               "church", "art_gallery", "amusement_park",
               "restaurant", "cafe", "bakery", "bar"
           ]) {
            logger.info("Name corrected: '\(poi.name)' → '\(googleName)' (Google Places)")
            enriched.name = googleName
        }

        enriched.googlePlaceId = placeId
        enriched.rating = details.rating
        enriched.reviewCount = details.userRatingsTotal
        enriched.phoneNumber = details.formattedPhoneNumber ?? poi.phoneNumber
        enriched.priceLevel = details.priceLevel
        enriched.isOpenNow = details.openingHours?.openNow
        enriched.detailedDescription = details.editorialSummary?.overview
        enriched.googlePlaceTypes = details.types ?? []

        // Correct category if Google types reveal a misclassification.
        // E.g., Apple Maps tagging a cafe as a landmark.
        if let types = details.types, !types.isEmpty {
            let googleCategory = POICategory.from(googleTypes: types)
            if googleCategory != .other && googleCategory != enriched.category {
                // Only reclassify if the Google category is more specific
                // (e.g., landmark → cafe, but not museum → landmark)
                let isDowngrade = enriched.category.isTouristAttraction && !googleCategory.isTouristAttraction
                let isCrossCategory = enriched.category.isTouristAttraction && googleCategory.isFood
                if isCrossCategory || isDowngrade {
                    logger.info("Category corrected: '\(poi.name)' \(enriched.category.rawValue) → \(googleCategory.rawValue) (Google Places)")
                    enriched.category = googleCategory
                }
            }
        }

        if let weekdayText = details.openingHours?.weekdayText {
            enriched.openingHours = weekdayText.joined(separator: "\n")
            enriched.openingHoursWeekdayText = weekdayText
        }

        if let websiteStr = details.website, let url = URL(string: websiteStr) {
            enriched.websiteURL = url
        }

        // Photos removed from Place Details field mask to stay on the Advanced
        // tier ($0.035/req) instead of Preferred ($0.04/req). Users can tap the
        // Google Maps link on the card for photos and more details.

        enriched.isEnriched = true
        await cache.set(poi.name, value: enriched)
        logger.debug("Enriched '\(poi.name)': rating=\(enriched.rating.map { String(format: "%.1f", $0) } ?? "nil"), reviews=\(enriched.reviewCount.map(String.init) ?? "nil")")
        return enriched
    }

    // MARK: - Private

    private func findPlaceId(for poi: POI) async -> String? {
        let location = "\(poi.location.latitude),\(poi.location.longitude)"
        let endpoint = GooglePlacesAPI.findPlace(
            query: poi.name,
            location: location,
            apiKey: apiKey
        )

        do {
            let response = try await apiClient.request(endpoint, responseType: GooglePlacesAPI.FindPlaceResponse.self)

            guard response.status == "OK" else {
                logger.warning("Find Place status=\(response.status) for '\(poi.name)': \(response.errorMessage ?? "no error message")")
                return nil
            }

            return response.candidates.first?.placeId
        } catch {
            logger.warning("Find place failed for \(poi.name): \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchDetails(placeId: String) async -> GooglePlacesAPI.PlaceDetailsResponse.PlaceResult? {
        let endpoint = GooglePlacesAPI.placeDetails(placeId: placeId, apiKey: apiKey)

        do {
            let response = try await apiClient.request(endpoint, responseType: GooglePlacesAPI.PlaceDetailsResponse.self)
            return response.result
        } catch {
            logger.warning("Place details failed: \(error.localizedDescription)")
            return nil
        }
    }
}
